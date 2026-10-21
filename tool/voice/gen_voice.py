# MeloTTS(MIT 라이선스, 한국어 모델)로 놀이터 음성 조각을 만든다.
# 사용: python gen_voice.py lines.json assets/voice [속도] [--all]  (tool/gen_voice.command 가 부른다)
#   --all 을 붙이면 이미 있는 녹음도 모두 새로 만든다 (목소리 설정을 바꿨을 때만).
# 녹음마다 child_voice.py 의 "어린이 느낌" 처리(피치 +5반음, 포먼트 ×1.12)와 음량 맞추기를 거친다.
# 그래서 나중에 문장을 더 넣고 다시 돌려도 새 문장이 같은 목소리로 나온다.
import json, os, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
redo_all = "--all" in sys.argv
lines_path, out_dir = args[0], args[1]
speed = float(args[2]) if len(args) > 2 else 0.8  # 0.8: 만 3세가 알아듣기 쉽게 조금 천천히
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
# manifest 는 기존 내용을 지우지 않고 합친다 (예전 번호를 다시 쓰다가 엉뚱한 녹음이 나오지 않게).
manifest_path = os.path.join(out_dir, "manifest.json")
manifest = {}
if os.path.exists(manifest_path):
    manifest = json.load(open(manifest_path, encoding="utf-8"))

todo = [it for it in lines if redo_all or not os.path.exists(os.path.join(out_dir, it["file"]))]
if redo_all:
    # 목록에서 빠졌지만 manifest 에 남아 있는 예전 문장도 같은 목소리로 다시 만든다
    known = {it["text"] for it in lines}
    todo += [{"file": f, "text": t} for t, f in manifest.items() if t not in known]
print(f"전체 {len(lines)}문장, 새로 만들 문장 {len(todo)}개", flush=True)

t0 = time.time()
if todo:
    import soundfile as sf
    from melo.api import TTS

    import child_voice

    model = TTS(language="KR", device="cpu")
    spk = model.hps.data.spk2id["KR"]
    tmp = os.path.join(out_dir, "_tmp.wav")
    for i, item in enumerate(todo):
        mp3 = os.path.join(out_dir, item["file"])
        model.tts_to_file(item["text"], spk, tmp, speed=speed, quiet=True)
        y, sr = sf.read(tmp)
        if y.ndim > 1:
            y = y.mean(axis=1)
        sf.write(tmp, child_voice.process(y, sr), sr, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
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
