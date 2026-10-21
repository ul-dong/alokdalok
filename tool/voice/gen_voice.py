# MeloTTS(MIT 라이선스, 한국어 모델)로 놀이터 음성 조각을 만든다.
import json, os, subprocess, sys, time

lines_path, out_dir = sys.argv[1], sys.argv[2]
speed = float(sys.argv[3]) if len(sys.argv) > 3 else 0.9
lines = json.load(open(lines_path, encoding="utf-8"))
os.makedirs(out_dir, exist_ok=True)

# 일본어용 MeCab 은 쓰지 않는다 (맥에서 한국어용 mecab 과 이름이 겹침). 불러오기만 되게 가짜로 채운다.
import types
_fake = types.ModuleType("MeCab")


class _Tagger:
    def __init__(self, *a, **k):
        pass

    def parse(self, s):
        return ""


_fake.Tagger = _Tagger
sys.modules.setdefault("MeCab", _fake)

from melo.api import TTS

model = TTS(language="KR", device="cpu")
spk = model.hps.data.spk2id["KR"]
tmp = os.path.join(out_dir, "_tmp.wav")
manifest = {}
t0 = time.time()
for i, item in enumerate(lines):
    mp3 = os.path.join(out_dir, item["file"])
    if not os.path.exists(mp3):
        model.tts_to_file(item["text"], spk, tmp, speed=speed, quiet=True)
        af = (
            "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
            "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
            "loudnorm=I=-16:TP=-1.5:LRA=11"
        )
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", af,
             "-ac", "1", "-ar", "24000", "-b:a", "40k", mp3],
            check=True,
        )
    manifest[item["text"]] = item["file"]
    print(f"{i + 1}/{len(lines)} {item['text']}", flush=True)
if os.path.exists(tmp):
    os.remove(tmp)
with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=0)
print(f"done in {time.time() - t0:.0f}s", flush=True)
