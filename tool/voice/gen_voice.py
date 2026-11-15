# MeloTTS(MIT 라이선스, 한국어·영어 모델)로 놀이터 음성 조각을 만든다.
# 사용: python gen_voice.py lines_ko.json assets/voice/ko [--lang=KR|EN] [--all]  (tool/gen_voice.command 가 부른다)
#   --lang: MeloTTS 언어 (KR 기본, EN 은 미국 영어 EN-US 목소리)
#   --all 을 붙이면 이미 있는 녹음도 모두 새로 만든다 (목소리 설정을 바꿨을 때만).
#   (예전처럼 세 번째 인자로 속도를 주면 그 속도로 만든다. 보통은 주지 않는다)
# 녹음마다 child_voice.py 의 언어별 처리(만화 캐릭터 느낌 억양, 따뜻한 EQ, 음량 맞추기)를 거친다.
# MeloTTS 설정(화자·속도·sdp_ratio 등)과 난수 씨앗도 child_voice.py 의 VOICES 에 있어서
# 같은 문장은 늘 같은 녹음이 나온다.
# 그래서 나중에 문장을 더 넣고 다시 돌려도 새 문장이 같은 목소리로 나온다.
import json, os, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
redo_all = "--all" in sys.argv
lang = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--lang=")), "KR")
lines_path, out_dir = args[0], args[1]
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import child_voice  # noqa: E402  (설정값만 먼저 읽는다. 무거운 모듈은 녹음할 때 불러온다)

melo = child_voice.VOICES[lang]["melo"]
speaker = melo["speaker"]
# 한국어는 빠르게(1.1) 만든 뒤 child_voice 가 PSOLA 로 1.34배 늘인다. 질문은 더 천천히(melo_speed)
speed = float(args[2]) if len(args) > 2 else None  # None: 문장마다 child_voice.melo_speed (질문은 천천히)
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
    import numpy as np
    import soundfile as sf
    import torch
    from melo.api import TTS

    model = TTS(language=lang, device="cpu")
    spk = model.hps.data.spk2id[speaker]
    tmp = os.path.join(out_dir, "_tmp.wav")
    def synth(text, seed):
        torch.manual_seed(seed)
        model.tts_to_file(text, spk, tmp, quiet=True,
                          speed=speed or child_voice.melo_speed(text, lang),
                          sdp_ratio=melo["sdp_ratio"],
                          noise_scale=melo["noise_scale"],
                          noise_scale_w=melo["noise_scale_w"])
        y, sr = sf.read(tmp)
        if y.ndim > 1:
            y = y.mean(axis=1)
        return y, sr

    def encode(z, sr, mp3):
        """mp3(24kHz 모노 64kbps)로 저장하고, 다시 읽은 소리를 돌려준다"""
        sf.write(tmp, z, sr, subtype="PCM_16")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
                        "-ac", "1", "-ar", "24000", "-b:a", "64k", mp3], check=True)
        raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", mp3, "-f", "f32le",
                              "-ac", "1", "-ar", "24000", "-"], capture_output=True, check=True).stdout
        return np.frombuffer(raw, np.float32).astype(np.float64), 24000

    # 처음 한 번은 모델 안쪽(BERT)을 불러오느라 난수를 써서 결과가 달라진다.
    # 버리는 문장을 먼저 한 번 만들어, 몇 번째로 만들든 같은 문장은 같은 녹음이 나오게 한다.
    synth("warm up" if lang == "EN" else "준비", child_voice.SEED)
    for i, item in enumerate(todo):
        mp3 = os.path.join(out_dir, item["file"])
        # MeloTTS 가 어떤 문장(s, sh, ch 가 많은 짧은 말)은 쉰 소리로 만든다.
        # 정해 둔 씨앗들로 다시 만들어 보고 가장 맑은(HNR 높은) 것을 고른다 (늘 같은 순서라 결과도 같다).
        best = None
        for seed in [child_voice.SEED] + child_voice.RETRY_SEEDS:
            y, sr = synth(item["text"], seed)
            z = child_voice.process(y, sr, item["text"], lang=lang)
            # mp3 로 바꾼 소리로도 튀는 곳을 다시 잰다 (점검 기준: 6반음, 3곳 이상이면 탈락)
            ok = child_voice.jumps(z, sr) <= child_voice.MAX_JUMPS and \
                child_voice.jumps(*encode(z, sr, mp3), semitones=6.0) < 3
            score = (ok, child_voice.hnr(z, sr))
            if best is None or score > best[0]:
                best = (score, z, seed)
            if score[0] and score[1] >= child_voice.HNR_GOAL:
                break
        encode(best[1], sr, mp3)
        print(f"{i + 1}/{len(todo)} {item['file']} {item['text']} (씨앗 {best[2]}, HNR {best[0][1]:.1f})", flush=True)
    if os.path.exists(tmp):
        os.remove(tmp)

for item in lines:
    if os.path.exists(os.path.join(out_dir, item["file"])):
        manifest[item["text"]] = item["file"]
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=0)
print(f"done in {time.time() - t0:.0f}s, 새 녹음 {len(todo)}개", flush=True)
