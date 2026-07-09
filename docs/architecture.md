# Architecture

## Shared package

`Packages/OneVoiceKit` contains three libraries:

- `OneVoiceCore` — sessions, transcript normalization, JSON history, dictionary replacement, hotkey gesture interpretation, and insertion contracts.
- `OneVoiceAppleSpeech` — the macOS/iOS 26 `SpeechAnalyzer` adapter. Incoming microphone buffers are converted to the analyzer's exact supported format and streamed through `SpeechTranscriber`.
- `OneVoiceQwenSpeech` — optional Qwen3-ASR model management and the hybrid engine. Apple Speech always drives the live preview; Qwen can replace only the completed final result.

## macOS

`OneVoiceMacModel` owns the recording state machine. `GlobalHotkeyMonitor` uses a listen-only event tap. It distinguishes Fn hold-to-talk from Right Command tap-to-toggle without swallowing normal keyboard input.

The focused Accessibility element and frontmost app are captured before recording. Final insertion follows this order:

1. Reject secure text fields and copy instead.
2. Set `AXSelectedText` when the focused field supports it.
3. Temporarily place text on the pasteboard, send Command-V to the captured process, and restore the previous pasteboard if it was not changed by another app.

The floating dictation panel is nonactivating, so it does not steal the insertion target.

## iOS

The iOS app uses the same session, history, dictionary, Apple Speech, and Qwen components. It presents recording, history, dictionary, and settings tabs. Completed transcripts are copied to the system pasteboard because iOS does not allow arbitrary cross-app field insertion.

## Persistence

- `history.json` and `dictionary.json` live in the app's Application Support directory.
- Quick dictation and voice-note audio are processed in memory and discarded.
- Qwen weights live under `Application Support/OneVoice/Models` and are excluded from device backup.
- Model downloads are resumable, size-checked, and SHA-256 verified before loading.

There is no account, telemetry, analytics SDK, cloud database, or application server.
