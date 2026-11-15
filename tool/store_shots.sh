#!/bin/zsh
# 알록달록 꼬마 놀이터 - Google Play 스토어 스크린샷 6장 (1280×800 가로, 한국어)
# test_preview 의 골든 렌더러(실제 글꼴 Jua)로 그린다. 실기기 촬영보다 일관되고 언제든 다시 뽑을 수 있다.
# 결과: tool/out/store_shots/{1_home,2_number,3_color,4_shop,5_character,6_eye_guard}.png (git 제외)
# STORE_DPR=2 tool/store_shots.sh  → 같은 화면을 2560×1600 으로 (더 선명한 태블릿용)
set -e
setopt null_glob
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/alokdev/flutter/bin/flutter}"
OUT="$REPO/tool/out/store_shots"
cd "$REPO"
rm -rf test_preview/shots/store
"$FLUTTER" test test_preview/store_shots_test.dart --update-goldens
mkdir -p "$OUT"
rm -f "$OUT"/*.png
cp test_preview/shots/store/*.png "$OUT/"
echo ""
echo "스크린샷: $OUT"
for f in "$OUT"/*.png; do
  echo "  $(basename "$f")  $(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
done
