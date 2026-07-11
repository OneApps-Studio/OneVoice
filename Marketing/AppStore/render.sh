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

render_slide en-US 1 01-record.png $'Record beyond\nthe lock screen' \
  'Private audio with automatic on-device transcripts.'
render_slide en-US 2 02-history.png $'Every recording,\ninstantly searchable' \
  'Keep the audio, read the transcript, find the moment.'
render_slide en-US 3 03-dictionary.png $'Teach it the words\nthat matter' \
  'Names, brands, and phrases come out the way you write them.'
render_slide en-US 4 04-settings.png $'Private iCloud sync,\non by default' \
  'Your recordings and transcripts stay in your private Apple database.'

render_slide zh-Hans 1 01-record.png $'离开 App，\n录音也不中断' \
  '音频私密保存，并在设备端自动生成转写。'
render_slide zh-Hans 2 02-history.png $'每段录音，\n都能快速搜索' \
  '保留音频、查看文本，随时找回关键内容。'
render_slide zh-Hans 3 03-dictionary.png $'自定义词典，\n写出正确名称' \
  '人名、品牌和专业词汇，都按你的习惯输出。'
render_slide zh-Hans 4 04-settings.png $'默认私有\niCloud 同步' \
  '录音与文本只进入你自己的 Apple 私有数据库。'
