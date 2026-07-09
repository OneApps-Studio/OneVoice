# Qwen3Speech subset used by OneVoice

This directory contains the minimal Qwen3-ASR batch-inference subset from
[`soniqo/speech-swift`](https://github.com/soniqo/speech-swift), pinned to commit
`8ed7919c525c2ea49e7e3e3d46316dbe360148de`.

Only `AudioCommon`, `MLXCommon`, and `Qwen3ASR` are included. The optional VAD,
TTS, server, CLI, and benchmark targets were intentionally omitted so OneVoice
does not resolve or ship unrelated dependencies. The upstream Apache-2.0
license is included in this directory.
