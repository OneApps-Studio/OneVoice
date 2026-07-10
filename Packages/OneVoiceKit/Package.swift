// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OneVoiceKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "OneVoiceCore", targets: ["OneVoiceCore"]),
        .library(name: "OneVoiceAppleSpeech", targets: ["OneVoiceAppleSpeech"]),
        .library(name: "OneVoiceCloudSync", targets: ["OneVoiceCloudSync"]),
        .library(name: "OneVoiceQwenSpeech", targets: ["OneVoiceQwenSpeech"]),
    ],
    dependencies: [
        .package(path: "../../ThirdParty/Qwen3Speech"),
    ],
    targets: [
        .target(name: "OneVoiceCore"),
        .target(
            name: "OneVoiceAppleSpeech",
            dependencies: ["OneVoiceCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
            ]
        ),
        .target(
            name: "OneVoiceCloudSync",
            dependencies: ["OneVoiceCore"],
            linkerSettings: [.linkedFramework("CloudKit")]
        ),
        .target(
            name: "OneVoiceQwenSpeech",
            dependencies: [
                "OneVoiceCore",
                .product(name: "Qwen3ASR", package: "Qwen3Speech"),
            ]
        ),
        .testTarget(
            name: "OneVoiceCoreTests",
            dependencies: ["OneVoiceCore"]
        ),
        .testTarget(
            name: "OneVoiceAppleSpeechTests",
            dependencies: ["OneVoiceAppleSpeech", "OneVoiceCore"],
            linkerSettings: [.linkedFramework("AVFoundation")]
        ),
        .testTarget(
            name: "OneVoiceCloudSyncTests",
            dependencies: ["OneVoiceCloudSync", "OneVoiceCore"]
        ),
        .testTarget(
            name: "OneVoiceQwenSpeechTests",
            dependencies: ["OneVoiceQwenSpeech"]
        ),
    ]
)
