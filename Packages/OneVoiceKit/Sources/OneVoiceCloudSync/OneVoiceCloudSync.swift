@preconcurrency import CloudKit
import Foundation
import OneVoiceCore

public enum OneVoiceCloudSyncStatus: Sendable, Equatable {
    case disabled
    case syncing
    case synced
    case unavailable
    case failed(String)

    public var displayText: String {
        switch self {
        case .disabled: "Off"
        case .syncing: "Syncing…"
        case .synced: "Synced"
        case .unavailable: "iCloud unavailable"
        case let .failed(message): "Sync error: \(message)"
        }
    }
}

public actor OneVoiceCloudSync: CKSyncEngineDelegate {
    public typealias StatusHandler = @Sendable (OneVoiceCloudSyncStatus) async -> Void
    public typealias ChangeHandler = @Sendable () async -> Void

    private let container: CKContainer
    private let database: CKDatabase
    private let zone: CKRecordZone
    private let stateFileURL: URL
    private let entryStore: VoiceEntryStore
    private let replacementStore: DictionaryReplacementStore
    private let recordingStore: VoiceRecordingStore?
    private let systemFieldsDirectoryURL: URL
    private let statusHandler: StatusHandler
    private let changeHandler: ChangeHandler
    private var engine: CKSyncEngine?
    private var started = false

    public init(
        containerIdentifier: String,
        stateFileURL: URL,
        entryStore: VoiceEntryStore,
        replacementStore: DictionaryReplacementStore,
        recordingStore: VoiceRecordingStore? = nil,
        statusHandler: @escaping StatusHandler = { _ in },
        changeHandler: @escaping ChangeHandler = {}
    ) {
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.database = container.privateCloudDatabase
        self.zone = CKRecordZone(zoneName: "OneVoiceSync")
        self.stateFileURL = stateFileURL
        self.entryStore = entryStore
        self.replacementStore = replacementStore
        self.recordingStore = recordingStore
        self.systemFieldsDirectoryURL = stateFileURL
            .deletingLastPathComponent()
            .appending(path: "cloud-record-system-fields", directoryHint: .isDirectory)
        self.statusHandler = statusHandler
        self.changeHandler = changeHandler
    }

    public func start() async {
        guard !started else { return }
        started = true
        await statusHandler(.syncing)
        do {
            guard try await container.accountStatus() == .available else {
                await statusHandler(.unavailable)
                started = false
                return
            }

            _ = try await database.save(zone)

            var configuration = CKSyncEngine.Configuration(
                database: database,
                stateSerialization: loadState(),
                delegate: self
            )
            configuration.automaticallySync = true
            let engine = CKSyncEngine(configuration)
            self.engine = engine

            try await engine.fetchChanges()
            await enqueueAllLocalRecords()
            try await engine.sendChanges()
            await statusHandler(.synced)
        } catch {
            await statusHandler(.failed(error.localizedDescription))
        }
    }

    public func stop() async {
        started = false
        await engine?.cancelOperations()
        engine = nil
        await statusHandler(.disabled)
    }

    public func save(_ entry: VoiceEntry) async {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [
            .saveRecord(OneVoiceCloudRecordCodec.entryRecordID(entry.id, zoneID: zone.zoneID)),
        ])
        await sendPendingChanges(using: engine)
    }

    public func deleteEntry(id: UUID) async {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [
            .deleteRecord(OneVoiceCloudRecordCodec.entryRecordID(id, zoneID: zone.zoneID)),
        ])
        await sendPendingChanges(using: engine)
    }

    public func save(_ replacement: DictionaryReplacement) async {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [
            .saveRecord(OneVoiceCloudRecordCodec.replacementRecordID(replacement.id, zoneID: zone.zoneID)),
        ])
        await sendPendingChanges(using: engine)
    }

    public func deleteReplacement(id: UUID) async {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [
            .deleteRecord(OneVoiceCloudRecordCodec.replacementRecordID(id, zoneID: zone.zoneID)),
        ])
        await sendPendingChanges(using: engine)
    }

    public func refresh() async {
        guard let engine else { return }
        await statusHandler(.syncing)
        do {
            try await engine.fetchChanges()
            await statusHandler(.synced)
        } catch {
            await statusHandler(.failed(error.localizedDescription))
        }
    }

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case let .stateUpdate(update):
            persist(update.stateSerialization)
        case let .fetchedRecordZoneChanges(changes):
            await apply(changes)
        case let .sentRecordZoneChanges(changes):
            await handleSentRecordChanges(changes, syncEngine: syncEngine)
        case .didFetchChanges, .didSendChanges:
            await statusHandler(.synced)
        case let .accountChange(change):
            switch change.changeType {
            case .signIn:
                await statusHandler(.syncing)
            case .signOut, .switchAccounts:
                await statusHandler(.unavailable)
            @unknown default:
                await statusHandler(.unavailable)
            }
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter(context.options.scope.contains)
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
            guard let self else { return nil }
            return await self.record(for: recordID)
        }
    }

    private func record(for recordID: CKRecord.ID) async -> CKRecord? {
        guard let local = OneVoiceCloudRecordCodec.localIdentifier(for: recordID) else { return nil }
        switch local.kind {
        case .entry:
            guard let entry = await entryStore.entry(id: local.id) else { return nil }
            let audioFileURL = await recordingStore?.fileURL(for: entry)
            let existingRecord = await existingRecord(recordID: recordID)
            return OneVoiceCloudRecordCodec.record(
                for: entry,
                zoneID: zone.zoneID,
                audioFileURL: audioFileURL,
                existingRecord: existingRecord
            )
        case .replacement:
            guard let replacement = await replacementStore.replacement(id: local.id) else { return nil }
            let record = await existingRecord(recordID: recordID) ?? CKRecord(
                recordType: OneVoiceCloudRecordCodec.replacementRecordType,
                recordID: recordID
            )
            record["id"] = replacement.id.uuidString as CKRecordValue
            record["spoken"] = replacement.spoken as CKRecordValue
            record["written"] = replacement.written as CKRecordValue
            return record
        }
    }

    private func apply(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        do {
            for modification in changes.modifications {
                let record = modification.record
                persistSystemFields(for: record)
                if var entry = OneVoiceCloudRecordCodec.entry(from: record) {
                    if let asset = record["audioAsset"] as? CKAsset,
                       let stagingURL = asset.fileURL,
                       let recordingStore {
                        let recording = try await recordingStore.importCloudAsset(
                            from: stagingURL,
                            id: entry.id
                        )
                        entry.audioFileName = recording.fileName
                        entry.audioByteCount = recording.byteCount
                    }
                    try await entryStore.save(entry)
                } else if let replacement = OneVoiceCloudRecordCodec.replacement(from: record) {
                    try await replacementStore.save(replacement)
                }
            }
            for deletion in changes.deletions {
                guard let local = OneVoiceCloudRecordCodec.localIdentifier(for: deletion.recordID) else { continue }
                removeSystemFields(for: deletion.recordID)
                switch local.kind {
                case .entry:
                    if let entry = await entryStore.entry(id: local.id) {
                        try await recordingStore?.deleteRecording(for: entry)
                    }
                    try await entryStore.delete(id: local.id)
                case .replacement: try await replacementStore.delete(id: local.id)
                }
            }
            await changeHandler()
        } catch {
            await statusHandler(.failed(error.localizedDescription))
        }
    }

    private func enqueueAllLocalRecords() async {
        guard let engine else { return }
        let entries = await entryStore.entries()
        let replacements = await replacementStore.all()
        let entryChanges = entries.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(
                OneVoiceCloudRecordCodec.entryRecordID($0.id, zoneID: zone.zoneID)
            )
        }
        let replacementChanges = replacements.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(
                OneVoiceCloudRecordCodec.replacementRecordID($0.id, zoneID: zone.zoneID)
            )
        }
        engine.state.add(pendingRecordZoneChanges: entryChanges + replacementChanges)
    }

    private func sendPendingChanges(using engine: CKSyncEngine) async {
        await statusHandler(.syncing)
        do {
            try await engine.sendChanges()
            await statusHandler(.synced)
        } catch {
            await statusHandler(.failed(error.localizedDescription))
        }
    }

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard FileManager.default.fileExists(atPath: systemFieldsDirectoryURL.path()) else {
            return nil
        }
        guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func persist(_ state: CKSyncEngine.State.Serialization) {
        do {
            try FileManager.default.createDirectory(
                at: stateFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            Task { await statusHandler(.failed(error.localizedDescription)) }
        }
    }

    private func existingRecord(recordID: CKRecord.ID) async -> CKRecord? {
        if let cached = loadSystemFields(for: recordID) {
            return cached
        }
        if let record = try? await database.record(for: recordID) {
            persistSystemFields(for: record)
            return record
        }
        return nil
    }

    private func handleSentRecordChanges(
        _ changes: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        changes.savedRecords.forEach(persistSystemFields)
        changes.deletedRecordIDs.forEach(removeSystemFields)

        var retries: [CKSyncEngine.PendingRecordZoneChange] = []
        for failure in changes.failedRecordSaves {
            if let serverRecord = failure.error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                persistSystemFields(for: serverRecord)
                retries.append(.saveRecord(failure.record.recordID))
            } else {
                await statusHandler(.failed(failure.error.localizedDescription))
            }
        }
        if !retries.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: retries)
        }
        if let error = changes.failedRecordDeletes.values.first {
            await statusHandler(.failed(error.localizedDescription))
        }
    }

    private func persistSystemFields(for record: CKRecord) {
        do {
            try FileManager.default.createDirectory(
                at: systemFieldsDirectoryURL,
                withIntermediateDirectories: true
            )
            let coder = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: coder)
            coder.finishEncoding()
            try coder.encodedData.write(to: systemFieldsURL(for: record.recordID), options: .atomic)
        } catch {
            Task { await statusHandler(.failed(error.localizedDescription)) }
        }
    }

    private func loadSystemFields(for recordID: CKRecord.ID) -> CKRecord? {
        guard let data = try? Data(contentsOf: systemFieldsURL(for: recordID)) else { return nil }
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }

    private func removeSystemFields(for recordID: CKRecord.ID) {
        try? FileManager.default.removeItem(at: systemFieldsURL(for: recordID))
    }

    private func systemFieldsURL(for recordID: CKRecord.ID) -> URL {
        systemFieldsDirectoryURL.appending(path: "\(recordID.recordName).record")
    }
}
