#!/usr/bin/env python3
"""Keep the OneVoice UI catalog limited to English and Simplified Chinese."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ZH_HANS: dict[str, str] = {
    "%arg×": "%arg×",
    "A transcript is not available for this recording.": "这段录音暂时没有可用的转写。",
    "About": "关于",
    "About 0.7–1 GB · Wi-Fi recommended": "约 0.7–1 GB · 建议使用 Wi-Fi",
    "About One Apps": "关于 One Apps",
    "About OneVoice": "关于 OneVoice",
    "Accurate Model": "高精度模型",
    "Apple On-Device": "Apple 设备端识别",
    "Back 15 Seconds": "后退 15 秒",
    "Contact": "联系我们",
    "Continue Recording": "继续录音",
    "Copyright © One Apps Studio": "版权所有 © One Apps Studio",
    "Data & Privacy": "数据与隐私",
    "Delete Recording": "删除录音",
    "Delete this recording?": "要删除这段录音吗？",
    "Done": "完成",
    "Downloading Qwen3-ASR… %arg%%": "正在下载 Qwen3-ASR… %arg%%",
    "Focused apps for everyday work, made with care for privacy and simplicity.": "专注日常所需，以隐私与简洁为先。",
    "Forward 15 Seconds": "前进 15 秒",
    "Help": "帮助",
    "Imported": "已导入",
    "Links": "链接",
    "Imports Stay Temporary": "导入文件仅临时处理",
    "Live Recognition": "实时识别",
    "Listening…": "正在聆听…",
    "Local-First": "本地优先",
    "Local-first. No account, ads, or analytics.": "本地优先，无需账号，没有广告或分析。",
    "More Actions": "更多操作",
    "More From One Apps": "更多 One Apps",
    "MLX Swift": "MLX Swift",
    "Models Stay on Device": "模型保留在设备上",
    "New Recording": "新录音",
    "No Ads or Analytics": "没有广告或分析",
    "No OneVoice Audio Server": "没有 OneVoice 音频服务器",
    "No recordings yet": "还没有录音",
    "Not Selected": "未选择",
    "OK": "好",
    "OneVoice": "OneVoice",
    "OneVoice %arg": "OneVoice %arg",
    "One Apps Studio": "One Apps Studio",
    "Open Source": "开源项目",
    "Optional high-accuracy offline final transcript": "可选的高精度离线最终转写",
    "Playback Position": "播放位置",
    "Playback Speed": "播放速度",
    "Policy": "政策",
    "Preferences": "偏好设置",
    "Privacy Policy": "隐私政策",
    "Privacy Promise": "隐私承诺",
    "Private iCloud": "私有 iCloud",
    "Product Page": "产品页面",
    "Qwen3-ASR 0.6B": "Qwen3-ASR 0.6B",
    "Qwen3-ASR": "Qwen3-ASR",
    "Recognition Language": "识别语言",
    "Record and transcribe on this device": "在此设备上录音并转写",
    "Record, transcribe, remember": "录下来，转成文字，随时找到",
    "Recording": "录音",
    "Recording and transcription start on your device, without a OneVoice account.": "录音与转写从你的设备开始，无需 OneVoice 账号。",
    "Recording unavailable": "录音不可用",
    "Recordings": "录音库",
    "Recordings, transcripts, and dictionary": "录音、转写与个人词典",
    "Remove Download": "移除下载",
    "Rename Recording": "重命名录音",
    "Save": "保存",
    "Search recordings": "搜索录音",
    "Selected": "已选择",
    "Source Code": "源代码",
    "Speak naturally": "自然说话即可",
    "Studio": "工作室",
    "Support": "支持",
    "Sync Library": "同步资料库",
    "Sync Now": "立即同步",
    "The audio and transcript will be removed from this device and your private iCloud library.": "音频与转写将从此设备和你的私有 iCloud 资料库中删除。",
    "The optional Qwen model is downloaded only when you request it and never syncs.": "只有在你主动请求时才会下载可选 Qwen 模型，且模型不会同步。",
    "Appearance": "外观",
    "Theme": "主题",
    "Title": "标题",
    "Transcript": "转写",
    "Try another title or phrase from a transcript.": "试试其他标题或转写中的词语。",
    "Untitled Recording": "未命名录音",
    "Use for Final Transcript": "用于最终转写",
    "Show Onboarding Again": "再次查看新手引导",
    "Version %arg (%arg)": "版本 %arg（%arg）",
    "When sync is on, voice-note audio, transcripts, and dictionary entries mirror through your private iCloud database.": "开启同步后，语音笔记音频、转写和词典条目会通过你的私有 iCloud 数据库镜像同步。",
    "Your Apple Account": "你的 Apple 账户",
    "Your recordings and searchable transcripts will appear here.": "你的录音和可搜索的转写会显示在这里。",
    "Your voice is never uploaded to a server operated by OneVoice or One Apps Studio.": "你的语音绝不会上传到 OneVoice 或 One Apps Studio 运营的服务器。",
    "Imported audio and video are transcribed on this device and are not added to your OneVoice library or iCloud.": "导入的音频与视频会在此设备上转写，不会加入 OneVoice 资料库或 iCloud。",
    "OneVoice does not include an analytics SDK or third-party tracking.": "OneVoice 不含分析 SDK 或第三方跟踪。",
    "Accessibility": "辅助功能",
    "Accurate Offline": "高精度离线识别",
    "After download, no network is needed for recognition.": "下载后，语音识别无需网络。",
    "Apple Speech gives you live text. Download Qwen3-ASR when you want a more accurate offline final pass.": "Apple 语音识别提供实时文字；需要更准确的离线最终结果时，可下载 Qwen3-ASR。",
    "Apple live preview": "Apple 实时预览",
    "Apple live · Qwen accurate final": "Apple 实时 · Qwen 高精度最终结果",
    "Apple on-device recognition": "Apple 设备端语音识别",
    "Cancel Starting": "取消启动",
    "Capture short thoughts or longer voice notes.": "记录简短想法或较长的语音笔记。",
    "Clean Blue": "清透蓝",
    "Copy or share the transcript into any app.": "将转写结果复制或分享到任意 App。",
    "Correct names and specialist vocabulary.": "修正姓名和专业词汇。",
    "Crisp, bright, and utility-first.": "清爽明亮，专注实用。",
    "Dark": "深色",
    "Dictate": "听写",
    "Download Model": "下载模型",
    "Download failed": "下载失败",
    "English": "英语",
    "Fast Live, Accurate Final": "实时快速，最终准确",
    "Fast feedback with system on-device speech.": "通过系统设备端语音识别快速获得反馈。",
    "Favorite": "收藏",
    "File transcription cancelled.": "已取消文件转写。",
    "Finalizing on device…": "正在设备端完成处理…",
    "Finish": "结束",
    "Finish Dictation": "结束听写",
    "Fn": "Fn",
    "Fresh Sage": "鼠尾草绿",
    "Granted": "已授权",
    "Graphite": "石墨灰",
    "Input Monitoring": "输入监控",
    "Installed": "已安装",
    "Installed and ready": "已安装，可以使用",
    "Keep searchable voice notes, teach OneVoice your vocabulary, and paste the result anywhere.": "保存可搜索的语音笔记，教会 OneVoice 你的词汇，并将结果粘贴到任何地方。",
    "Left Command": "左 Command",
    "Left Control": "左 Control",
    "Left Option": "左 Option",
    "Light": "浅色",
    "Live transcription": "实时转写",
    "Microphone": "麦克风",
    "No account required": "无需账号",
    "Not installed": "未安装",
    "Off": "已关闭",
    "Open the app and start talking.": "打开 App 即可开始说话。",
    "Optional": "可选",
    "Optional 0.6B model for more accurate offline text.": "可选的 0.6B 模型，可提供更准确的离线文字。",
    "Pause": "暂停",
    "Play": "播放",
    "Preparing download…": "正在准备下载…",
    "Preparing private recognition…": "正在准备私密识别…",
    "Private by design": "隐私优先设计",
    "Quiet, focused, and neutral.": "安静、专注且中性。",
    "Qwen3-ASR final pass": "Qwen3-ASR 最终识别",
    "Recognition": "语音识别",
    "Record in the foreground or background, then transcribe on device. OneVoice has no audio server.": "无论前台还是后台都可录音，随后在设备端完成转写。OneVoice 没有音频服务器。",
    "Recording and transcribing on this device": "正在此设备上录音并转写",
    "Recordings and transcripts stay local-first and can sync through your private iCloud account.": "录音和转写以本地保存为主，并可通过你的私有 iCloud 账户同步。",
    "Required": "需要授权",
    "Right Command": "右 Command",
    "Right Control": "右 Control",
    "Right Option": "右 Option",
    "Running accurate offline final pass…": "正在进行高精度离线最终识别…",
    "Secure fields cannot be filled automatically. The transcript was copied.": "安全输入框不会自动填充，转写已复制。",
    "Simplified Chinese": "简体中文",
    "Soft, calm, and close to the OneVoice icon.": "柔和、平静，与 OneVoice 图标相呼应。",
    "Speak, Save, Share": "说出、保存、分享",
    "Speech Recognition": "语音识别",
    "Speech Recognition permission is required.": "需要语音识别权限。",
    "Status": "状态",
    "Stop": "停止",
    "Sync error": "同步错误",
    "Synced": "已同步",
    "Syncing…": "正在同步…",
    "System": "跟随系统",
    "Tap to record": "点击录音",
    "Teach OneVoice a term": "教 OneVoice 认识一个词",
    "Teach your terms": "教会它你的词汇",
    "Transcript saved.": "转写已保存。",
    "Unfavorite": "取消收藏",
    "Use device language": "使用设备语言",
    "Use it anywhere": "在任何地方使用",
    "Warm Sand": "暖砂色",
    "Warmer and more editorial.": "更温暖，更具编辑感。",
    "Watch words appear as you speak.": "说话时即可看到文字实时出现。",
    "Works offline": "离线可用",
    "Your Voice Stays Yours": "你的声音始终属于你",
    "Your replacements": "你的替换规则",
    "iCloud Sync": "iCloud 同步",
    "iCloud unavailable": "iCloud 不可用",
    "at login": "登录时",
    "·": "·",
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    targets = [
        (
            root / "IOSAPP/OneVoice/Localizable.xcstrings",
            root / "IOSAPP/OneVoice",
        ),
        (
            root / "MACAPP/OneVoiceMac/Localizable.xcstrings",
            root / "MACAPP/OneVoiceMac",
        ),
    ]
    for catalog_path, source_root in targets:
        current = json.loads(catalog_path.read_text(encoding="utf-8"))
        current_strings: dict[str, dict[str, object]] = current.get("strings", {})

        with tempfile.TemporaryDirectory(prefix="onevoice-strings-") as temporary_root:
            output_directory = Path(temporary_root) / "catalog"
            potential_directory = Path(temporary_root) / "potential"
            output_directory.mkdir()
            potential_directory.mkdir()
            swift_sources = sorted(str(path) for path in source_root.rglob("*.swift"))
            subprocess.run(
                [
                    "xcrun",
                    "xcstringstool",
                    "extract",
                    *swift_sources,
                    "--SwiftUI",
                    "--modern-localizable-strings",
                    "--output-format",
                    "xcstrings",
                    "--output-directory",
                    str(output_directory),
                ],
                check=True,
            )
            subprocess.run(
                [
                    "xcrun",
                    "xcstringstool",
                    "extract",
                    *swift_sources,
                    "--SwiftUI",
                    "--modern-localizable-strings",
                    "--all-potential-swift-keys",
                    "--output-directory",
                    str(potential_directory),
                ],
                check=True,
            )
            potential_keys: set[str] = set()
            for strings_data_path in potential_directory.glob("*.stringsdata"):
                strings_data = json.loads(strings_data_path.read_text(encoding="utf-8"))
                for records in strings_data.get("tables", {}).values():
                    potential_keys.update(
                        record["key"] for record in records if record.get("key")
                    )

            extracted_path = output_directory / "Localizable.xcstrings"
            catalog = json.loads(extracted_path.read_text(encoding="utf-8"))

        strings: dict[str, dict[str, object]] = catalog.get("strings", {})

        # Xcode's extractor does not discover string literals passed through our
        # LocalizedStringResource-based OneRow/OneSection components. Keep those
        # explicit keys in the catalog so the custom design system still follows
        # the app locale at runtime.
        for key in potential_keys.intersection(ZH_HANS):
            strings.setdefault(key, {})

        missing_translations: list[str] = []
        for key, record in strings.items():
            existing_translation = (
                current_strings.get(key, {})
                .get("localizations", {})
                .get("zh-Hans", {})
                .get("stringUnit", {})
                .get("value")
            )
            translation = ZH_HANS.get(key, existing_translation)
            if translation:
                record["localizations"] = {
                    "zh-Hans": {
                        "stringUnit": {"state": "translated", "value": translation}
                    }
                }
            else:
                missing_translations.append(key)

        if missing_translations:
            formatted = "\n".join(f"- {key}" for key in missing_translations)
            raise SystemExit(f"Missing zh-Hans translations in {catalog_path}:\n{formatted}")

        catalog["sourceLanguage"] = "en"
        catalog["strings"] = dict(sorted(strings.items()))
        catalog["version"] = "1.0"
        catalog_path.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
