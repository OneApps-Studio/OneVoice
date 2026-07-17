#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MAGICK="${MAGICK:-/opt/homebrew/bin/magick}"
EN_FONT="/System/Library/Fonts/SFNS.ttf"
ZH_FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"

render_slide() {
  local locale="$1"
  local index="$2"
  local source_name="$3"
  local headline="$4"
  local subtitle="$5"
  local font="$EN_FONT"
  if [[ "$locale" == "zh-Hans" ]]; then
    font="$ZH_FONT"
  fi

  local source="$ROOT/source/$locale/iphone/$source_name"
  local destination="$ROOT/generated/$locale/iphone-6.9/$source_name"
  mkdir -p "$(dirname "$destination")"

  "$MAGICK" \
    -size 1320x2868 'gradient:#FAF9F1-#DFEBE1' \
    -colorspace sRGB \
    -fill '#2E6F5B' -font "$font" -pointsize 32 \
    -gravity northwest -annotate +90+56 "ONEVOICE  ·  $index / 4" \
    -fill '#101713' -font "$font" -pointsize 84 -interline-spacing -8 \
    -gravity northwest -annotate +90+112 "$headline" \
    -fill '#52615A' -font "$font" -pointsize 34 \
    -gravity northwest -annotate +92+315 "$subtitle" \
    \( "$source" -resize 1080x2348! -bordercolor white -border 10x10 \) \
    -gravity northwest -geometry +110+420 -composite \
    -alpha off -strip -colorspace sRGB -depth 8 \
    "$destination"
}

render_slide en-US 1 01-library.png $'Record once,\nfind it anytime' \
  'Private recordings with searchable on-device transcripts.'
render_slide en-US 2 02-player.png $'Replay every detail,\nat your pace' \
  'Scrub, skip, and change speed with a real audio waveform.'
render_slide en-US 3 03-dictionary.png $'Teach it the words\nthat matter' \
  'Names, brands, and phrases come out the way you write them.'
render_slide en-US 4 04-settings.png $'Private sync,\nacross iPhone and Mac' \
  'Your recordings and transcripts stay in your private Apple database.'

render_slide zh-Hans 1 01-library.png $'录一次，\n以后随时找到' \
  '录音私密保存，并在设备端生成可搜索的转写。'
render_slide zh-Hans 2 02-player.png $'每个细节，\n都能按需回放' \
  '真实波形、进度拖动、快进快退与倍速播放。'
render_slide zh-Hans 3 03-dictionary.png $'自定义词典，\n写出正确名称' \
  '人名、品牌和专业词汇，都按你的习惯输出。'
render_slide zh-Hans 4 04-settings.png $'私有同步，\niPhone 与 Mac 随时接续' \
  '录音与文本只进入你自己的 Apple 私有数据库。'
