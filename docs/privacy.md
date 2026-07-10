# Privacy model

OneVoice is local-first by design.

- Microphone buffers are sent only to recognizers running on the device.
- Quick dictation audio and iOS voice-note audio are never written to disk.
- Transcripts, favorites, and personal dictionary replacements are stored locally as JSON.
- OneVoice does not contain an account system, advertising SDK, analytics SDK, crash-reporting SDK, or telemetry endpoint.
- OneVoice itself connects only after the user chooses to download the optional Qwen3-ASR model. Apple may separately download and manage on-device Speech assets through the operating system.
- Downloaded model weights are not uploaded and are excluded from iCloud backup.
- macOS secure text fields are not filled. Their result is copied to the clipboard for an explicit user paste.

Apple Speech assets are installed and managed by the operating system. Qwen model files are pinned to a known repository revision and verified before use.
