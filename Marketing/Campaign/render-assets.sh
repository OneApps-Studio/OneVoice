#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/Marketing/Campaign/output"
SITE="${ONEAPPS_ASSET_ROOT:-$ROOT/../../Sites/OneApps.Studio/apps/web/public/one-apps}"
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
ICON="$SITE/assets/onevoice-icon.png"
PHONE="$SITE/products/onevoice/onevoice-library-zh.webp"
MAC="$SITE/products/onevoice/onevoice-transcribe-file.webp"

if [[ ! -f "$ICON" || ! -f "$PHONE" || ! -f "$MAC" ]]; then
  echo "One Apps website assets not found. Set ONEAPPS_ASSET_ROOT to the one-apps public asset directory." >&2
  exit 1
fi

mkdir -p "$OUT"

poster() {
  local file="$1" bg="$2" accent="$3" eyebrow="$4" headline="$5" body="$6" footer="$7"
  magick -size 1080x1350 "xc:$bg" \
    \( "$ICON" -resize 150x150 \) -geometry +80+76 -composite \
    -font "$FONT" -fill "$accent" -pointsize 34 -gravity northwest -annotate +260+105 "$eyebrow" \
    -fill '#F7F7F2' -pointsize 92 -interline-spacing -8 -gravity northwest \
    -annotate +80+280 "$headline" \
    -fill '#C9CBC7' -pointsize 38 -interline-spacing 12 -gravity northwest \
    -annotate +84+650 "$body" \
    -fill "$accent" -draw 'roundrectangle 80,1115 1000,1255 36,36' \
    -fill '#111311' -pointsize 34 -gravity south -annotate +0+138 "$footer" \
    -strip -quality 84 -define webp:method=6 \
    "$OUT/$file"
}

poster "onevoice-a-private.webp" '#111311' '#B8F36B' 'ONEVOICE · 免费 / 开源 / 离线' \
  $'你的声音，\n不该先上传\n再被听见。' \
  $'本地完成语音识别\n没有账号 · 没有广告\n没有 OneVoice 音频服务器' \
  '免费使用 · oneapps.studio/apps/onevoice'

poster "onevoice-b-fast.webp" '#12172A' '#7CCBFF' 'ONEVOICE · 任意 APP 全局语音输入' \
  $'打字跟不上想法，\n就别再打字。' \
  $'按住 Fn 开始说话\n松开，文字自动写入光标处\n离线也能正常工作' \
  'Mac 免费下载 · 开箱即用'

poster "onevoice-c-free.webp" '#211416' '#FF9B73' 'ONEVOICE · 不按分钟计费' \
  $'语音输入，\n不该又是\n一笔订阅。' \
  $'不限次数 · 不限时长\nMac 全局输入 + iPhone 语音笔记\n代码完全开源' \
  '你的设备 · 你的模型 · 你的声音'

# 适合公众号文章头图、博客和横版社交媒体。
magick -size 1600x900 xc:'#0E110F' \
  \( "$MAC" -resize 780x620 \
     -bordercolor '#273029' -border 2 -background none \
     \( +clone -background '#00000080' -shadow 45x18+0+22 \) +swap -background none -layers merge +repage \) \
  -geometry +760+150 -composite \
  \( "$ICON" -resize 112x112 \) -geometry +90+76 -composite \
  -font "$FONT" -fill '#B8F36B' -pointsize 30 -gravity northwest -annotate +230+100 'ONEVOICE · 免费 / 开源 / 离线' \
  -fill '#F7F7F2' -pointsize 78 -interline-spacing -5 -annotate +90+280 $'你的声音，\n不必离开\n你的设备。' \
  -fill '#BFC4BE' -pointsize 31 -annotate +94+660 $'按住 Fn，说完即写入。\n没有账号、广告或音频服务器。' \
  -strip -quality 84 -define webp:method=6 \
  "$OUT/onevoice-landscape-private.webp"

# 正方形信息流封面：免费钩子。
magick -size 1080x1080 xc:'#211416' \
  \( "$ICON" -resize 132x132 \) -geometry +74+68 -composite \
  -font "$FONT" -fill '#FF9B73' -pointsize 30 -gravity northwest -annotate +236+105 'ONEVOICE · 免费且开源' \
  -fill '#F8F4F1' -pointsize 86 -interline-spacing -8 -annotate +76+300 $'语音输入，\n不该又是\n一笔订阅。' \
  -fill '#CFBFBA' -pointsize 32 -annotate +80+765 $'不限次数 · 不按分钟收费\nMac + iPhone · 离线优先' \
  -strip -quality 84 -define webp:method=6 \
  "$OUT/onevoice-square-free.webp"

# iPhone 功能宣传图。
magick -size 1080x1350 xc:'#101421' \
  \( "$PHONE" -resize 410x890 \) -geometry +620+250 -composite \
  -font "$FONT" -fill '#7CCBFF' -pointsize 30 -gravity northwest -annotate +74+74 'ONEVOICE FOR IPHONE' \
  -fill '#F4F7FA' -pointsize 76 -interline-spacing -7 -annotate +74+230 $'录下来。\n自动转写。\n随时找到。' \
  -fill '#BAC6D0' -pointsize 32 -interline-spacing 10 -annotate +78+650 $'支持后台录音\n保存原始音频\n全文搜索转写\n私人 iCloud 同步' \
  -fill '#7CCBFF' -draw 'roundrectangle 70,1150 550,1265 30,30' \
  -fill '#101421' -pointsize 30 -annotate +118+1187 'App Store 免费获取' \
  -strip -quality 84 -define webp:method=6 \
  "$OUT/onevoice-iphone-notes.webp"

# 开源与信任宣传图。
magick -size 1080x1350 xc:'#111311' \
  \( "$ICON" -resize 150x150 \) -geometry +74+70 -composite \
  -font "$FONT" -fill '#B8F36B' -pointsize 30 -gravity northwest -annotate +260+104 'ONEVOICE · APACHE-2.0' \
  -fill '#F7F7F2' -pointsize 82 -interline-spacing -7 -annotate +74+300 $'不是免费试用。\n是真的免费。' \
  -fill '#C9CBC7' -pointsize 36 -interline-spacing 13 -annotate +78+690 $'代码完全开源\n没有会员墙\n没有每日次数限制\n没有分析 SDK' \
  -fill '#B8F36B' -pointsize 30 -annotate +78+1160 'github.com/OneApps-Studio/OneVoice' \
  -strip -quality 84 -define webp:method=6 \
  "$OUT/onevoice-open-source.webp"

# 竖屏短视频：三张海报依次出现，适合视频号、小红书、抖音和朋友圈。
ffmpeg -y \
  -loop 1 -t 4.6 -i "$OUT/onevoice-a-private.webp" \
  -loop 1 -t 4.6 -i "$OUT/onevoice-b-fast.webp" \
  -loop 1 -t 4.6 -i "$OUT/onevoice-c-free.webp" \
  -filter_complex "[0:v]scale=1080:1350,pad=1080:1920:0:285:color=#111311,fade=t=in:st=0:d=0.35,fade=t=out:st=4.1:d=0.5[v0];[1:v]scale=1080:1350,pad=1080:1920:0:285:color=#12172A,fade=t=in:st=0:d=0.35,fade=t=out:st=4.1:d=0.5[v1];[2:v]scale=1080:1350,pad=1080:1920:0:285:color=#211416,fade=t=in:st=0:d=0.35,fade=t=out:st=4.1:d=0.5[v2];[v0][v1][v2]concat=n=3:v=1:a=0,format=yuv420p[v]" \
  -map '[v]' -r 30 -c:v libx264 -crf 18 -movflags +faststart \
  "$OUT/onevoice-promo-vertical.mp4"

echo "$OUT"
