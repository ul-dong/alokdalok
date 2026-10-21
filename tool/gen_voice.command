#!/bin/zsh
# 알록달록 꼬마 놀이터 - 무료 음성 모델(MeloTTS, MIT)로 녹음 목소리 만들기
# 1) lib/services/voice_lines.dart 의 문장 목록을 tool/voice/lines.json 으로 내보내고
# 2) assets/voice 에 녹음(mp3)이 없는 문장만 새로 만들어 넣은 뒤
# 3) assets/voice/manifest.json 을 갱신한다 (기존 녹음은 건드리지 않는다).
# 새 녹음은 모두 tool/voice/child_voice.py 의 어린이 느낌 처리를 거친다 (기존 녹음과 같은 목소리).
# 전부 다시 녹음하려면: tool/gen_voice.command --all
# 필요: Homebrew (python@3.10, ffmpeg 은 자동 설치), Flutter 는 ~/alokdev/flutter.
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ROOT="$HOME/alokdev"
OUT="$REPO/assets/voice"
mkdir -p "$REPO/build"
LOG="$REPO/build/voice_log.txt"
exec > >(tee "$LOG") 2>&1
# 작업하는 동안만 맥이 잠자기/화면 꺼짐으로 넘어가지 않게 한다 (끝나면 kill 로 푼다)
caffeinate -dimsu -w $$ & CAF=$!
finish() { kill $CAF 2>/dev/null || true; [ "${ALOK_NONINTERACTIVE:-0}" = "1" ] || read -r "?창을 닫으려면 Enter를 누르세요"; }
fail() { echo ""; echo "오류: $1"; finish; exit 1; }
step() { echo ""; echo "==== $1 ===="; }
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
command -v brew > /dev/null || fail "Homebrew가 없어요 (https://brew.sh 에서 먼저 설치)"
export PATH="$ROOT/flutter/bin:$PATH"
command -v flutter > /dev/null || fail "Flutter가 없어요 (install_and_build.command 먼저)"

step "1/5 문장 목록 내보내기"
cd "$REPO"
flutter pub get > /dev/null || fail "pub get 실패"
flutter test tool/voice/export_lines_test.dart || fail "문장 목록 내보내기 실패"

step "2/5 파이썬과 ffmpeg"
brew list python@3.10 > /dev/null 2>&1 || brew install python@3.10 || fail "python 설치 실패"
brew list ffmpeg > /dev/null 2>&1 || brew install ffmpeg || fail "ffmpeg 설치 실패"
PY="$(brew --prefix python@3.10)/bin/python3.10"

step "3/5 음성 모델 설치 (처음엔 10분 정도)"
VENV="$ROOT/melo-venv"
[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV" || fail "venv 실패"
source "$VENV/bin/activate"
if ! pip show melotts > /dev/null 2>&1; then
  pip install -U pip wheel "setuptools<70" || fail "pip 업데이트 실패"
  pip install "numpy==1.26.4" "git+https://github.com/myshell-ai/MeloTTS.git" "python-mecab-ko" || fail "MeloTTS 설치 실패"
  python -m unidic download || fail "사전 받기 실패"
fi
pip install -q "setuptools<70" "numpy==1.26.4" || fail "setuptools/numpy 고정 실패"
# 어린이 느낌 목소리 처리(tool/voice/child_voice.py)에 쓰는 Praat
python -c "import parselmouth" 2>/dev/null || pip install -q "praat-parselmouth==0.4.7" "numpy==1.26.4" || fail "parselmouth 설치 실패"
python -c "import nltk; [nltk.download(p, quiet=True) for p in ['averaged_perceptron_tagger','averaged_perceptron_tagger_eng','cmudict']]" || true
# 맥은 대소문자를 구분하지 않아 일본어용 MeCab 과 한국어용 mecab 폴더가 겹친다.
# 한국어용만 남기고, 일본어용은 gen_voice.py 안에서 가짜로 채운다.
if ! python -c "import mecab; mecab.MeCab().pos('안녕')" 2>/dev/null; then
  pip uninstall -y mecab-python3 python-mecab-ko
  pip install --force-reinstall --no-deps python-mecab-ko || fail "mecab-ko 설치 실패"
fi
python -c "import mecab; mecab.MeCab().pos('안녕하세요')" || fail "mecab 확인 실패"

step "4/5 없는 문장만 녹음 → assets/voice"
python "$HERE/voice/gen_voice.py" "$HERE/voice/lines.json" "$OUT" 0.8 "$@" || fail "음성 만들기 실패 (위 메시지 참고)"

step "5/5 완료"
echo "녹음 파일 $(ls "$OUT" | grep -c mp3)개. git status 로 새 mp3 와 manifest.json 을 확인하고 커밋하세요."
echo "확인: flutter test (음성 팩 테스트가 빠진 조각을 알려 줘요)"
finish
