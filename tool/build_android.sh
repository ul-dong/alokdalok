#!/bin/zsh
# 알록달록 꼬마 놀이터 - Google Play 업로드용 AAB(Android App Bundle) 빌드 (업로드는 하지 않는다)
# 결과: build/alokdalok.aab
#
# 서명은 install_and_build.command 와 같은 방식이다.
#   - android/key.properties (git 제외): storeFile=<키 저장소 경로>, keyAlias=alokdalok
#   - 비밀번호는 환경 변수 ALOK_STORE_PASSWORD (키 비밀번호가 다르면 ALOK_KEY_PASSWORD)
#     비어 있으면 화면에 보이지 않게 한 번 물어본다. 파일에는 절대 적지 않는다.
# 출시 키가 없으면 멈춘다. 크기·매니페스트 점검만 하려면 --debug-signed 를 붙인다
#   (debug 키로 서명된 AAB 는 Play 에 올릴 수 없다. 결과 이름도 alokdalok-DEBUG-SIGNED.aab).
#
# 쓰는 법: tool/build_android.sh [--debug-signed] [flutter build appbundle 옵션 ...]
#   예) tool/build_android.sh --build-number=3
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ALOKDEV="${ALOKDEV:-$HOME/alokdev}"
FLUTTER="${FLUTTER:-$ALOKDEV/flutter/bin/flutter}"
if [ -z "$JAVA_HOME" ]; then
  JAVA_HOME=$(ls -d "$ALOKDEV"/jdk-17*/Contents/Home 2>/dev/null | head -1 || true)
  export JAVA_HOME
fi
[ -d "$ALOKDEV/android-sdk" ] && export ANDROID_HOME="${ANDROID_HOME:-$ALOKDEV/android-sdk}"

DEBUG_SIGNED=0
if [ "$1" = "--debug-signed" ]; then DEBUG_SIGNED=1; shift; fi

KEYPROPS="$REPO/android/key.properties"
if [ $DEBUG_SIGNED = 1 ]; then
  # build.gradle.kts 는 비밀번호가 없으면 debug 키로 서명한다
  unset ALOK_STORE_PASSWORD ALOK_KEY_PASSWORD
  echo "주의: debug 키로 서명합니다. 이 AAB 는 크기·매니페스트 점검용이며 Play 에 올릴 수 없습니다."
else
  if [ ! -f "$KEYPROPS" ]; then
    echo "출시용 키가 없습니다: $KEYPROPS"
    echo "  storeFile=<키 저장소(.jks) 경로>"
    echo "  keyAlias=alokdalok"
    echo "를 적은 파일을 만든 뒤 다시 실행하세요 (키 만들기: install_and_build.command 6단계, docs/RELEASE.md)."
    echo "점검만 하려면: tool/build_android.sh --debug-signed"
    exit 1
  fi
  if [ -z "$ALOK_STORE_PASSWORD" ]; then
    read -rs "?키 저장소 비밀번호 (화면에 안 보여요): " ALOK_STORE_PASSWORD; echo ""
  fi
  [ -n "$ALOK_STORE_PASSWORD" ] || { echo "비밀번호가 비어 있어 멈춥니다."; exit 1; }
  export ALOK_STORE_PASSWORD
fi

cd "$REPO"
"$FLUTTER" pub get
# arm(휴대폰·태블릿) + x86_64(크롬북). Play 가 기기마다 맞는 조각만 내려보낸다.
"$FLUTTER" build appbundle --release \
  --target-platform android-arm,android-arm64,android-x64 "$@"
unset ALOK_STORE_PASSWORD ALOK_KEY_PASSWORD

SRC="build/app/outputs/bundle/release/app-release.aab"
if [ $DEBUG_SIGNED = 1 ]; then OUT="build/alokdalok-DEBUG-SIGNED.aab"; else OUT="build/alokdalok.aab"; fi
cp "$SRC" "$OUT"

# 서명 확인 (debug 키면 CN=Android Debug)
SIGNER=$("$JAVA_HOME/bin/keytool" -J-Duser.language=en -printcert -jarfile "$OUT" 2>/dev/null | grep -m1 "^Owner:" || true)
echo ""
echo "AAB: $REPO/$OUT ($(du -h "$OUT" | cut -f1))"
echo "서명: ${SIGNER:-알 수 없음}"
echo "ABI 별 네이티브 라이브러리 (압축 크기 합, 기기는 자기 ABI 하나만 받는다):"
unzip -v "$OUT" | awk '$NF ~ /^base\/lib\// { split($NF, p, "/"); s[p[3]] += $3 }
  END { for (a in s) printf "  %-12s %6.1f MB\n", a, s[a] / 1e6 }'
if [ $DEBUG_SIGNED = 0 ] && echo "$SIGNER" | grep -q "Android Debug"; then
  echo "오류: release 키 대신 debug 키로 서명되었습니다 (key.properties 의 storeFile 경로를 확인하세요)."
  exit 1
fi
