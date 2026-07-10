# Privacy model

OneVoice is local-first by design.

- Microphone buffers are sent only to recognizers running on the device.
- macOS quick-dictation audio is never written to disk.
- iOS voice-note audio is stored locally as compressed `.m4a` files so recordings can be replayed and searched later.
- Transcripts, favorites, and personal dictionary replacements are stored locally as JSON.
- Private iCloud sync is enabled by default. It mirrors iOS voice-note audio, transcript metadata, and dictionary replacements through the user's private CloudKit database so their Apple devices can access the same library. Users can turn it off in Settings.
- Imported media, macOS quick-dictation audio, and downloaded model weights never enter CloudKit.
- OneVoice does not contain an account system, advertising SDK, analytics SDK, crash-reporting SDK, or telemetry endpoint.
- OneVoice connects to Apple iCloud when private sync is enabled and to the pinned model host only after the user chooses to download Qwen3-ASR. Apple may separately download and manage on-device Speech assets through the operating system.
- Downloaded model weights are not uploaded and are excluded from iCloud backup.
- macOS secure text fields are not filled. Their result is copied to the clipboard for an explicit user paste.

Apple Speech assets are installed and managed by the operating system. Qwen model files are pinned to a known repository revision and verified before use.
