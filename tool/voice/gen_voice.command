#!/bin/zsh
# 알록달록 꼬마 놀이터 - 무료 음성 모델(MeloTTS, MIT)로 녹음 목소리 만들기
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HOME/alokdev"
LOG="$HERE/voice_log.txt"
exec > >(tee "$LOG") 2>&1
fail() { echo ""; echo "오류: $1"; echo "FAIL $1" > "$HERE/VOICE_DONE.txt"; read -r "?창을 닫으려면 Enter를 누르세요"; exit 1; }
step() { echo ""; echo "==== $1 ===="; }
rm -f "$HERE/VOICE_DONE.txt"
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
command -v brew > /dev/null || fail "Homebrew가 없어요 (ios_run.command 먼저)"

step "1/4 파이썬과 ffmpeg"
brew list python@3.10 > /dev/null 2>&1 || brew install python@3.10 || fail "python 설치 실패"
brew list ffmpeg > /dev/null 2>&1 || brew install ffmpeg || fail "ffmpeg 설치 실패"
PY="$(brew --prefix python@3.10)/bin/python3.10"

step "2/4 음성 모델 설치 (처음엔 10분 정도)"
VENV="$ROOT/melo-venv"
[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV" || fail "venv 실패"
source "$VENV/bin/activate"
pip install -q "setuptools<70" "numpy==1.26.4" 2>/dev/null
if ! pip show melotts > /dev/null 2>&1; then
  pip install -U pip wheel "setuptools<70" || fail "pip 업데이트 실패"
  pip install "numpy==1.26.4" "git+https://github.com/myshell-ai/MeloTTS.git" "python-mecab-ko" || fail "MeloTTS 설치 실패"
  python -m unidic download || fail "사전 받기 실패"
fi
python -c "import nltk; [nltk.download(p, quiet=True) for p in ['averaged_perceptron_tagger','averaged_perceptron_tagger_eng','cmudict']]" || true

pip install "setuptools<70" || fail "setuptools 고정 실패"
# 맥은 대소문자를 구분하지 않아 일본어용 MeCab 과 한국어용 mecab 폴더가 겹친다.
# 한국어용만 남기고, 일본어용은 gen_voice.py 안에서 가짜로 채운다.
if ! python -c "import mecab; mecab.MeCab().pos('안녕')" 2>/dev/null; then
  pip uninstall -y mecab-python3 python-mecab-ko
  pip install --force-reinstall --no-deps python-mecab-ko || fail "mecab-ko 설치 실패"
fi
python -c "import mecab; print(mecab.MeCab().pos('안녕하세요'))" || fail "mecab 확인 실패"


step "3/4 음성 만들기 (409개)"
python "$HERE/voice/gen_voice.py" "$HERE/voice/lines.json" "$HERE/voice/out" 0.9 || fail "음성 만들기 실패 (위 메시지 참고)"

step "4/4 완료"
echo "OK $(ls "$HERE/voice/out" | grep -c mp3)" > "$HERE/VOICE_DONE.txt"
echo "완료! 이 창은 닫아도 돼요."
read -r "?창을 닫으려면 Enter를 누르세요"
