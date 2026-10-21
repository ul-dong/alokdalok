# MeloTTS(MIT 라이선스, 한국어 모델)로 놀이터 음성 조각을 만든다.
# 사용: python gen_voice.py lines.json assets/voice [속도]  (tool/gen_voice.command 가 부른다)
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

# 녹음 파일이 이미 있는 문장은 건너뛴다. 새로 만들 것이 없으면 모델도 불러오지 않는다.
todo = [it for it in lines if not os.path.exists(os.path.join(out_dir, it["file"]))]
print(f"전체 {len(lines)}문장, 새로 만들 문장 {len(todo)}개", flush=True)

# manifest 는 기존 내용을 지우지 않고 합친다 (예전 번호를 다시 쓰다가 엉뚱한 녹음이 나오지 않게).
manifest_path = os.path.join(out_dir, "manifest.json")
manifest = {}
if os.path.exists(manifest_path):
    manifest = json.load(open(manifest_path, encoding="utf-8"))

t0 = time.time()
if todo:
    from melo.api import TTS

    model = TTS(language="KR", device="cpu")
    spk = model.hps.data.spk2id["KR"]
    tmp = os.path.join(out_dir, "_tmp.wav")
    af = (
        "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
        "loudnorm=I=-16:TP=-1.5:LRA=11"
    )
    for i, item in enumerate(todo):
        mp3 = os.path.join(out_dir, item["file"])
        model.tts_to_file(item["text"], spk, tmp, speed=speed, quiet=True)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", af,
             "-ac", "1", "-ar", "24000", "-b:a", "40k", mp3],
            check=True,
        )
        print(f"{i + 1}/{len(todo)} {item['file']} {item['text']}", flush=True)
    if os.path.exists(tmp):
        os.remove(tmp)

for item in lines:
    if os.path.exists(os.path.join(out_dir, item["file"])):
        manifest[item["text"]] = item["file"]
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=0)
print(f"done in {time.time() - t0:.0f}s, 새 녹음 {len(todo)}개", flush=True)
