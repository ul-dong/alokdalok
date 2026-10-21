#!/bin/zsh
# 알록달록 꼬마 놀이터 - macOS에서 Flutter/Android 도구를 갖추고 release APK를 만든다.
# - 모든 도구는 ~/alokdev 에만 설치한다 (관리자 암호 불필요).
# - 이 저장소 폴더의 소스를 그대로 빌드한다. 결과: build/alokdalok.apk
# - arm 전용(armeabi-v7a, arm64-v8a). ML Kit 얼굴 인식은 Play 서비스 버전.
# - release 서명: android/key.properties(커밋 안 함)에 키 위치만 적고, 비밀번호는 매번 직접 입력한다.
#   키가 없으면 처음 한 번 만들지 물어본다. 키 없이 진행하면 debug 키로 서명된다(직접 설치용으로만).
# - ALOK_NONINTERACTIVE=1 이면 아무것도 묻지 않고 debug 키로 빌드한다 (자동 점검용).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HOME/alokdev"
OUT="$HERE/build"
LOG="$OUT/install_log.txt"
mkdir -p "$ROOT" "$OUT"
exec > >(tee "$LOG") 2>&1
# 작업하는 동안만 맥이 잠자기/화면 꺼짐으로 넘어가지 않게 한다 (끝나면 kill 로 푼다)
caffeinate -dimsu -w $$ & CAF=$!
ASK=1; [ "${ALOK_NONINTERACTIVE:-0}" = "1" ] && ASK=0

finish() { kill $CAF 2>/dev/null || true; if [ $ASK = 1 ]; then read -r "?창을 닫으려면 Enter를 누르세요"; fi; return 0; }
step() { echo ""; echo "==== $1 ===="; }
fail() { echo "오류: $1"; echo "FAIL $1" > "$OUT/BUILD_DONE.txt"; echo ""; trap - ERR; finish; exit 1; }
download() { # url out
  if [ -f "$2" ]; then echo "이미 받음: $2"; return; fi
  echo "받는 중: $1"
  curl -L --fail --retry 3 -o "$2.part" "$1" || fail "다운로드 실패: $1"
  mv "$2.part" "$2"
}
trap 'fail "예상하지 못한 오류 (위 메시지 참고)"' ERR
rm -f "$OUT/BUILD_DONE.txt"

if [ "$(uname -m)" = "arm64" ]; then
  FLUTTER_ZIP=flutter_macos_arm64_3.47.7-stable.zip; JDK_ARCH=aarch64
else
  FLUTTER_ZIP=flutter_macos_3.47.7-stable.zip; JDK_ARCH=x64
fi

step "1/7 Java JDK 17"
JDK_DIR=$(ls -d "$ROOT"/jdk-17*/Contents/Home 2>/dev/null | head -1 || true)
if [ -z "$JDK_DIR" ]; then
  download "https://api.adoptium.net/v3/binary/latest/17/ga/mac/$JDK_ARCH/jdk/hotspot/normal/eclipse" "$ROOT/jdk17.tar.gz"
  tar -xzf "$ROOT/jdk17.tar.gz" -C "$ROOT" && rm "$ROOT/jdk17.tar.gz"
  JDK_DIR=$(ls -d "$ROOT"/jdk-17*/Contents/Home | head -1)
fi
export JAVA_HOME="$JDK_DIR"
echo "JAVA_HOME = $JAVA_HOME"

step "2/7 Flutter SDK (처음이면 약 1.5GB)"
if [ ! -x "$ROOT/flutter/bin/flutter" ]; then
  download "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/$FLUTTER_ZIP" "$ROOT/flutter.zip"
  echo "압축 푸는 중..."
  unzip -q "$ROOT/flutter.zip" -d "$ROOT" && rm "$ROOT/flutter.zip"
fi
export PATH="$ROOT/flutter/bin:$JAVA_HOME/bin:$PATH"

step "3/7 Android 명령줄 도구"
SDK="$ROOT/android-sdk"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKM" ]; then
  mkdir -p "$SDK/cmdline-tools"
  download "https://dl.google.com/android/repository/commandlinetools-mac-9862592_latest.zip" "$ROOT/clt.zip"
  unzip -q "$ROOT/clt.zip" -d "$SDK/cmdline-tools" && rm "$ROOT/clt.zip"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
fi
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"

step "4/7 Android SDK 구성 요소"
yes | "$SDKM" --licenses > /dev/null || true
"$SDKM" "platform-tools" "platforms;android-36" "build-tools;36.0.0" > /dev/null

step "5/7 Flutter 설정"
flutter config --no-analytics > /dev/null
flutter config --android-sdk "$SDK" --jdk-dir "$JAVA_HOME" > /dev/null
yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

step "6/7 release 서명 키"
KEYDIR="$ROOT/keys"
KEYPROPS="$HERE/android/key.properties"
unset ALOK_STORE_PASSWORD ALOK_KEY_PASSWORD
if [ $ASK = 1 ]; then
  if [ ! -f "$KEYPROPS" ]; then
    echo "release 서명 키가 아직 없어요."
    echo "만들면 $KEYDIR/alokdalok-release.jks 에 저장합니다 (저장소 밖, 꼭 따로 백업하세요)."
    read -r "?지금 만들까요? (y = 만들기 / Enter = debug 키로 빌드) " MAKE
    if [ "$MAKE" = "y" ]; then
      mkdir -p "$KEYDIR"
      echo "keytool 이 비밀번호(6자 이상)를 두 번 묻습니다. 이 비밀번호를 잊으면 같은 앱으로 업데이트할 수 없어요."
      keytool -genkeypair -v -keystore "$KEYDIR/alokdalok-release.jks" -alias alokdalok \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Alokdalok, O=Alokdalok, C=KR" || fail "키 만들기 실패"
      printf 'storeFile=%s\nkeyAlias=alokdalok\n' "$KEYDIR/alokdalok-release.jks" > "$KEYPROPS"
      echo "키 위치를 $KEYPROPS 에 적었어요 (비밀번호는 적지 않아요, git에도 안 올라가요)."
    fi
  fi
  if [ -f "$KEYPROPS" ]; then
    read -rs "?키 저장소 비밀번호 (화면에 안 보여요): " ALOK_STORE_PASSWORD; echo ""
    export ALOK_STORE_PASSWORD ALOK_KEY_PASSWORD="$ALOK_STORE_PASSWORD"
  fi
fi
[ -n "$ALOK_STORE_PASSWORD" ] && echo "release 키로 서명합니다." || echo "debug 키로 서명합니다 (내 기기에 직접 설치용)."

step "7/7 APK 만들기 (처음엔 5~10분)"
cd "$HERE"
flutter pub get
flutter build apk --release --target-platform android-arm,android-arm64
unset ALOK_STORE_PASSWORD ALOK_KEY_PASSWORD
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/alokdalok.apk"
SIZE=$(du -h "$OUT/alokdalok.apk" | cut -f1)
echo ""
echo "완료! APK: $OUT/alokdalok.apk ($SIZE)"
echo "OK $OUT/alokdalok.apk $SIZE" > "$OUT/BUILD_DONE.txt"
trap - ERR
[ $ASK = 1 ] && open -R "$OUT/alokdalok.apk"
echo ""
finish
