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
    private let journalFileURL: URL
    private let statusHandler: StatusHandler
    private let changeHandler: ChangeHandler
    private var journal: OneVoiceCloudSyncJournal
    private var engine: CKSyncEngine?
    private var started = false
    private var isSynchronizing = false
    private var cloudReady = false
    private var lastFailureMessage: String?

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
        self.journalFileURL = stateFileURL
            .deletingLastPathComponent()
            .appending(path: "cloud-sync-journal.json")
        self.journal = Self.loadJournal(
            from: stateFileURL
                .deletingLastPathComponent()
                .appending(path: "cloud-sync-journal.json")
        )
        self.statusHandler = statusHandler
        self.changeHandler = changeHandler
    }

    public func start() async {
        guard !started else { return }
        started = true
        let engine = ensureEngine()
        replayLocalJournal(into: engine)
        await synchronizeIfPossible(using: engine)
    }

    public func stop() async {
        started = false
        cloudReady = false
        await engine?.cancelOperations()
        engine = nil
        await statusHandler(.disabled)
    }

    public func save(_ entry: VoiceEntry) async {
        let recordID = OneVoiceCloudRecordCodec.entryRecordID(entry.id, zoneID: zone.zoneID)
        let action: OneVoiceCloudSyncJournal.Action = OneVoiceCloudRecordPolicy.shouldSync(entry)
            ? .save
            : .delete
        await stageLocalMutation(recordID: recordID, action: action)
    }

    public func deleteEntry(id: UUID) async {
        await stageLocalMutation(
            recordID: OneVoiceCloudRecordCodec.entryRecordID(id, zoneID: zone.zoneID),
            action: .delete
        )
    }

    public func save(_ replacement: DictionaryReplacement) async {
        await stageLocalMutation(
            recordID: OneVoiceCloudRecordCodec.replacementRecordID(replacement.id, zoneID: zone.zoneID),
            action: .save
        )
    }

    public func deleteReplacement(id: UUID) async {
        await stageLocalMutation(
            recordID: OneVoiceCloudRecordCodec.replacementRecordID(id, zoneID: zone.zoneID),
            action: .delete
        )
    }

    public func refresh() async {
        let engine = ensureEngine()
        replayLocalJournal(into: engine)
        await synchronizeIfPossible(using: engine)
    }

    private func synchronizeIfPossible(using engine: CKSyncEngine) async {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }
        await statusHandler(.syncing)
        do {
            guard try await container.accountStatus() == .available else {
                cloudReady = false
                await statusHandler(.unavailable)
                return
            }
            try await synchronize(using: engine)
        } catch {
            await reportFailure(error)
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
            await reportSteadyState()
        case let .accountChange(change):
            switch change.changeType {
            case .signIn:
                cloudReady = false
                await refresh()
            case .signOut, .switchAccounts:
                cloudReady = false
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
            guard let entry = await entryStore.entry(id: local.id),
                  OneVoiceCloudRecordPolicy.shouldSync(entry) else { return nil }
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
        var didChange = false
        var failureMessages: [String] = []
        for modification in changes.modifications {
            let record = modification.record
            do {
                didChange = try await applyRemoteRecord(record) || didChange
                journal.acknowledgeRemoteRetry(recordName: record.recordID.recordName, action: .save)
            } catch {
                journal.stageRemoteRetry(recordName: record.recordID.recordName, action: .save)
                failureMessages.append(error.localizedDescription)
            }
        }
        for deletion in changes.deletions {
            do {
                didChange = try await applyRemoteDeletion(deletion.recordID) || didChange
                journal.acknowledgeRemoteRetry(
                    recordName: deletion.recordID.recordName,
                    action: .delete
                )
            } catch {
                journal.stageRemoteRetry(recordName: deletion.recordID.recordName, action: .delete)
                failureMessages.append(error.localizedDescription)
            }
        }
        do {
            try persistJournal()
        } catch {
            failureMessages.append(error.localizedDescription)
        }
        if didChange {
            await changeHandler()
        }
        if let failure = failureMessages.first {
            lastFailureMessage = failure
            await statusHandler(.failed(failure))
        }
    }

    private func enqueueAllLocalRecords() async {
        guard let engine else { return }
        let entries = await entryStore.entries()
        let replacements = await replacementStore.all()
        for entry in entries {
            let recordID = OneVoiceCloudRecordCodec.entryRecordID(entry.id, zoneID: zone.zoneID)
            let action: OneVoiceCloudSyncJournal.Action = OneVoiceCloudRecordPolicy.shouldSync(entry)
                ? .save
                : .delete
            stageLocalMutation(recordID: recordID, action: action, into: engine)
        }
        for replacement in replacements {
            stageLocalMutation(
                recordID: OneVoiceCloudRecordCodec.replacementRecordID(
                    replacement.id,
                    zoneID: zone.zoneID
                ),
                action: .save,
                into: engine
            )
        }
        do {
            try persistJournal()
        } catch {
            await reportFailure(error)
        }
    }

    private func sendPendingChanges(using engine: CKSyncEngine) async {
        await statusHandler(.syncing)
        lastFailureMessage = nil
        do {
            try await engine.sendChanges()
            await reportSteadyState()
        } catch {
            await reportFailure(error)
        }
    }

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
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
        let stillPending = Set(syncEngine.state.pendingRecordZoneChanges.map(\.recordID.recordName))
        for record in changes.savedRecords {
            persistSystemFields(for: record)
            if !stillPending.contains(record.recordID.recordName) {
                journal.acknowledgeLocal(recordName: record.recordID.recordName, action: .save)
            }
        }
        for recordID in changes.deletedRecordIDs {
            removeSystemFields(for: recordID)
            if !stillPending.contains(recordID.recordName) {
                journal.acknowledgeLocal(recordName: recordID.recordName, action: .delete)
            }
        }
        do {
            try persistJournal()
        } catch {
            await reportFailure(error)
        }

        var retries: [CKSyncEngine.PendingRecordZoneChange] = []
        for failure in changes.failedRecordSaves {
            if let serverRecord = failure.error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                persistSystemFields(for: serverRecord)
                retries.append(.saveRecord(failure.record.recordID))
            } else {
                lastFailureMessage = failure.error.localizedDescription
                await statusHandler(.failed(failure.error.localizedDescription))
            }
        }
        if !retries.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: retries)
        }
        if let error = changes.failedRecordDeletes.values.first {
            lastFailureMessage = error.localizedDescription
            await statusHandler(.failed(error.localizedDescription))
        } else if changes.failedRecordSaves.isEmpty,
                  journal.localMutations.isEmpty,
                  journal.remoteRetries.isEmpty {
            lastFailureMessage = nil
        }
    }

    private func ensureEngine() -> CKSyncEngine {
        if let engine { return engine }
        var configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: loadState(),
            delegate: self
        )
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        return engine
    }

    private func synchronize(using engine: CKSyncEngine) async throws {
        lastFailureMessage = nil
        _ = try await database.save(zone)
        cloudReady = true
        replayLocalJournal(into: engine)
        if !journal.localMutations.isEmpty {
            try await engine.sendChanges()
        }
        try await retryFailedRemoteApplications()
        try await engine.fetchChanges()
        try await retryFailedRemoteApplications()
        await enqueueAllLocalRecords()
        try await engine.sendChanges()
        await reportSteadyState()
    }

    private func stageLocalMutation(
        recordID: CKRecord.ID,
        action: OneVoiceCloudSyncJournal.Action
    ) async {
        let engine = ensureEngine()
        stageLocalMutation(recordID: recordID, action: action, into: engine)
        do {
            try persistJournal()
        } catch {
            await reportFailure(error)
            return
        }
        guard cloudReady else { return }
        await sendPendingChanges(using: engine)
    }

    private func stageLocalMutation(
        recordID: CKRecord.ID,
        action: OneVoiceCloudSyncJournal.Action,
        into engine: CKSyncEngine
    ) {
        journal.stageLocal(recordName: recordID.recordName, action: action)
        switch action {
        case .save:
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        case .delete:
            engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        }
    }

    private func replayLocalJournal(into engine: CKSyncEngine) {
        for mutation in journal.localMutations.values {
            let recordID = CKRecord.ID(recordName: mutation.recordName, zoneID: zone.zoneID)
            switch mutation.action {
            case .save:
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .delete:
                engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
            }
        }
    }

    private func applyRemoteRecord(_ record: CKRecord) async throws -> Bool {
        if let localMutation = journal.localMutations[record.recordID.recordName] {
            if localMutation.action == .save {
                persistSystemFields(for: record)
            }
            return false
        }
        if var entry = OneVoiceCloudRecordCodec.entry(from: record) {
            guard OneVoiceCloudRecordPolicy.shouldSync(entry) else {
                if let engine {
                    stageLocalMutation(recordID: record.recordID, action: .delete, into: engine)
                    try persistJournal()
                }
                return false
            }
            if let asset = record["audioAsset"] as? CKAsset,
               let stagingURL = asset.fileURL,
               let recordingStore {
                let recording = try await recordingStore.importCloudAsset(from: stagingURL, id: entry.id)
                entry.audioFileName = recording.fileName
                entry.audioByteCount = recording.byteCount
            }
            try await entryStore.save(entry)
            persistSystemFields(for: record)
            return true
        }
        if let replacement = OneVoiceCloudRecordCodec.replacement(from: record) {
            try await replacementStore.save(replacement)
            persistSystemFields(for: record)
            return true
        }
        return false
    }

    private func applyRemoteDeletion(_ recordID: CKRecord.ID) async throws -> Bool {
        if journal.localMutations[recordID.recordName]?.action == .save {
            removeSystemFields(for: recordID)
            return false
        }
        guard let local = OneVoiceCloudRecordCodec.localIdentifier(for: recordID) else { return false }
        switch local.kind {
        case .entry:
            if let entry = await entryStore.entry(id: local.id) {
                try await recordingStore?.deleteRecording(for: entry)
            }
            try await entryStore.delete(id: local.id)
        case .replacement:
            try await replacementStore.delete(id: local.id)
        }
        removeSystemFields(for: recordID)
        return true
    }

    private func retryFailedRemoteApplications() async throws {
        guard !journal.remoteRetries.isEmpty else { return }
        var didChange = false
        var firstError: Error?
        for retry in journal.remoteRetries.values {
            let recordID = CKRecord.ID(recordName: retry.recordName, zoneID: zone.zoneID)
            do {
                switch retry.action {
                case .save:
                    do {
                        let record = try await database.record(for: recordID)
                        didChange = try await applyRemoteRecord(record) || didChange
                    } catch let error as CKError where error.code == .unknownItem {
                        didChange = try await applyRemoteDeletion(recordID) || didChange
                    }
                case .delete:
                    didChange = try await applyRemoteDeletion(recordID) || didChange
                }
                journal.acknowledgeRemoteRetry(recordName: retry.recordName, action: retry.action)
            } catch {
                firstError = firstError ?? error
            }
        }
        try persistJournal()
        if didChange { await changeHandler() }
        if let firstError { throw firstError }
    }

    private func reportFailure(_ error: Error) async {
        lastFailureMessage = error.localizedDescription
        await statusHandler(.failed(error.localizedDescription))
    }

    private func reportSteadyState() async {
        if let lastFailureMessage {
            await statusHandler(.failed(lastFailureMessage))
        } else if journal.localMutations.isEmpty, journal.remoteRetries.isEmpty {
            await statusHandler(.synced)
        } else {
            await statusHandler(.syncing)
        }
    }

    private static func loadJournal(from url: URL) -> OneVoiceCloudSyncJournal {
        guard let data = try? Data(contentsOf: url),
              let journal = try? JSONDecoder().decode(OneVoiceCloudSyncJournal.self, from: data)
        else { return OneVoiceCloudSyncJournal() }
        return journal
    }

    private func persistJournal() throws {
        try FileManager.default.createDirectory(
            at: journalFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(journal).write(to: journalFileURL, options: .atomic)
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

private extension CKSyncEngine.PendingRecordZoneChange {
    var recordID: CKRecord.ID {
        switch self {
        case let .saveRecord(recordID), let .deleteRecord(recordID): recordID
        @unknown default:
            preconditionFailure("Unsupported CKSyncEngine pending record-zone change")
        }
    }
}
