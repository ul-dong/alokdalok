# 어른 목소리(MeloTTS 한국어 화자)를 만 3세에게 친근한 "어린이 느낌" 목소리로 바꾸고,
# 다정한 서울 말투 억양을 입힌다. (2026-10 샘플 "5_서울말투"로 고른 목소리)
#
# 방법: Praat(parselmouth, GPL 도구지만 결과 음성에는 아무 조건이 없다)로 한 번의 PSOLA 처리
#   - 목소리 높이(피치) 중앙값을 +5 반음 올리고, 포먼트(입 안 울림 자리)는 ×1.12 만 올린다
#     (Change gender 와 같은 방법: 샘플링 주파수를 1.12배로 읽어 포먼트를 올리고 PSOLA 로 피치·길이를 맞춤)
#   - 억양: 첫머리를 조금 높게 시작해 점점 내려오고, 칭찬("잘했어요")은 첫 음절에 강세,
#     질문("~까요?")은 끝 음절을 부드럽게 올리고, 감탄·평서("~요!")는 끝을 올렸다가 살짝 내린다.
#     마지막 음절은 1.3배로 늘인다. 숫자 세기 조각("하나"…"열")은 이어 붙여도 어색하지 않게 약하게만.
#   - 억양과 피치를 한 번에 처리해야 금속성 소리가 늘지 않는다.
# 그다음 말끝을 덜 자르고(-55dB, 150ms 남기고 120ms 페이드), 따뜻한 EQ·부드러운 압축을 거쳐,
# 모든 조각을 같은 크기(-16 LUFS, 최대 -1.5 dBFS)로 고정 배율로 맞춘다.
#
# gen_voice.py 가 새 문장을 녹음할 때마다 이 처리를 거치므로, 나중에 추가한 문장도 같은 목소리가 된다.
import math
import os
import subprocess
import tempfile

import numpy as np
from scipy.signal import lfilter, resample_poly

# 다른 사람이 바꿔 볼 수 있게 숫자를 한곳에 모았다
PITCH_SEMITONES = 5.0  # 원래 목소리 중앙값에서 몇 반음 올릴지
FORMANT_RATIO = 1.12  # 포먼트 이동 비율 (1.0 = 그대로, 1.2 이상은 다람쥐 소리 위험)
PITCH_RANGE = 1.15  # 억양 폭 (반음 단위로 넓힘)
TARGET_LUFS = -16.0
PEAK_DBFS = -1.5
SILENCE_DB = -45.0  # 앞뒤 무음 자르기 기준 (최대값 대비, 예전 방식 trim)
PAD_SEC = 0.03  # 예전 방식 trim 에서 앞뒤로 남기는 여유

# MeloTTS 설정: 기본값(sdp 0.2, noise 0.6/0.8)보다 억양 변화를 키워 낭독조를 줄인다
MELO = dict(speed=0.82, sdp_ratio=0.5, noise_scale=0.65, noise_scale_w=0.9)
SEED = 1234  # 같은 문장은 늘 같은 녹음이 나오게

# 서울 말투 억양 (반음)
DECL = 1.5  # 첫머리를 이만큼 높게 시작해 끝으로 내려온다 (평균 높이는 그대로)
ACCENT = 2.0  # 칭찬 첫 음절 강세
Q_RISE = 6.0  # 질문 끝 음절을 부드럽게 올리는 폭
RF = 3.5  # 감탄·평서 끝 음절: 이만큼 올렸다가
RF_END = -0.5  # 끝은 음절 시작보다 이만큼
STRETCH = 1.3  # 마지막 음절 늘이기

# 말끝 덜 자르기
GENTLE_DB = -55.0
TAIL_SEC = 0.15
TAIL_FADE = 0.12

# 따뜻한 EQ·압축 (ffmpeg): 하이패스 90Hz, 300Hz +2.5dB, 7kHz -3dB, 2:1 압축
POST = ("highpass=f=90:poles=2,"
        "equalizer=f=300:t=q:w=0.9:g=2.5,"
        "equalizer=f=7000:t=q:w=0.8:g=-3,"
        "acompressor=threshold=-20dB:ratio=2:attack=15:release=180:knee=6:makeup=1")

# 숫자 세기 조각: 도장 박자에 맞춰 한 마디씩 이어 말하므로 억양을 약하게
COUNTING = {"하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉", "열"}


def change_voice(y, sr, pitch_semitones=PITCH_SEMITONES, formant_ratio=FORMANT_RATIO,
                 pitch_range=PITCH_RANGE):
    """Praat Change gender. 원래 피치 중앙값을 재서 그보다 pitch_semitones 만큼 높게 맞춘다."""
    import parselmouth
    from parselmouth.praat import call

    snd = parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr)
    pitch = call(snd, "To Pitch", 0.0, 75, 600)
    median = call(pitch, "Get quantile", 0, 0, 0.5, "Hertz")
    if not median or math.isnan(median):
        median = 210.0  # 소리가 너무 짧아 피치를 못 잰 경우 (MeloTTS 화자 평균)
    new_median = median * 2 ** (pitch_semitones / 12)
    out = call(snd, "Change gender", 75, 600, formant_ratio, new_median, pitch_range, 1.0)
    return np.asarray(out.values[0], dtype=np.float64)


def trim(y, sr, silence_db=SILENCE_DB, pad=PAD_SEC):
    """앞뒤 무음 자르기 (10ms 창 RMS 기준)"""
    hop = max(1, int(sr * 0.01))
    n = len(y) // hop
    if n == 0:
        return y
    rms = np.sqrt(np.mean(y[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms / (rms.max() + 1e-12))
    on = np.where(db > silence_db)[0]
    if len(on) == 0:
        return y
    a = max(0, on[0] * hop - int(pad * sr))
    b = min(len(y), (on[-1] + 1) * hop + int(pad * sr))
    y = y[a:b].copy()
    f = min(len(y) // 4, int(0.008 * sr))  # 자른 자리에 딸깍 소리가 나지 않게
    if f > 1:
        ramp = 0.5 - 0.5 * np.cos(np.pi * np.arange(f) / f)
        y[:f] *= ramp
        y[-f:] *= ramp[::-1]
    return y


def _kweight(x, sr):
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / sr)
    vh = 10 ** (g / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / sr)
    a0 = 1 + k / q + k * k
    a2 = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    return lfilter([1, -2, 1], a2, lfilter(b1, a1, x))


def loudness(y, sr):
    """BS.1770 통합 음량(LUFS). 아주 짧은 조각("둘")도 재도록 창을 조각 길이에 맞춘다."""
    k = _kweight(y, sr)
    blk = min(int(0.4 * sr), len(k))
    hop = max(1, blk // 4)
    ms = np.array([np.mean(k[i:i + blk] ** 2) for i in range(0, len(k) - blk + 1, hop)])
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    ms = ms[lk > -70]
    if len(ms) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(ms)) - 10
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    return -0.691 + 10 * np.log10(np.mean(ms[lk > rel]))


def normalize(y, sr, target=TARGET_LUFS, peak_db=PEAK_DBFS):
    """고정 배율로 음량을 맞추고, 최대값이 넘치면 그 조각만 살짝 낮춘다 (압축하지 않는다)"""
    y = y * 10 ** ((target - loudness(y, sr)) / 20)
    ceil = 10 ** (peak_db / 20)
    peak = np.max(np.abs(y)) + 1e-12
    if peak > ceil:
        # 아주 짧은 첫 소리만 튀는 경우가 많아 천장 근처만 부드럽게 누른다
        thr = ceil * 0.8
        a = np.abs(y)
        over = a > thr
        y[over] = np.sign(y[over]) * (thr + (ceil - thr) * np.tanh((a[over] - thr) / (ceil - thr)))
    return y


def gentle_trim(y, sr, silence_db=GENTLE_DB, pad=TAIL_SEC, fade=TAIL_FADE, head_pad=0.04):
    """말끝을 덜 자르는 무음 자르기: 말끝 뒤로 150ms 를 남기고 그 끝 120ms 를 코사인으로 줄인다"""
    hop = max(1, int(sr * 0.01))
    n = len(y) // hop
    if n == 0:
        return y
    rms = np.sqrt(np.mean(y[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms / (rms.max() + 1e-12))
    on = np.where(db > silence_db)[0]
    if len(on) == 0:
        return y
    a = max(0, on[0] * hop - int(head_pad * sr))
    end = (on[-1] + 1) * hop + int(pad * sr)
    y = np.concatenate([y[a:min(len(y), end)], np.zeros(max(0, end - len(y)))])
    f = int(fade * sr)
    if f > 1 and len(y) > 2 * f:
        y[-f:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(f) / f)
        h = int(0.01 * sr)
        y[:h] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(h) / h)
    return y


def kind_of(text):
    """끝 억양 종류: q(질문) e(감탄·평서) count(숫자 세기) name(문장 조각·이름)"""
    t = text.strip()
    if t in COUNTING:
        return "count"
    if t.endswith("?"):
        return "q"
    if t[-1:] in "!.":
        return "e"
    return "name"


def _smooth(x):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, x)))


def final_shape(kind, x):
    """마지막 음절 모양 (음절 시작 높이 기준, 반음). x: 0~1"""
    if kind == "q":  # 부드럽게 올린다
        return Q_RISE * _smooth(x)
    if kind == "e":  # 살짝 올렸다가 내린다
        if x < 0.4:
            return RF * _smooth(x / 0.4)
        return RF + (RF_END - RF) * _smooth((x - 0.4) / 0.6)
    if kind == "count":  # "하나~": 아주 살짝 올렸다가 제자리 (이어 세어도 자연스럽게)
        if x < 0.5:
            return 1.2 * _smooth(x / 0.5)
        return 1.2 - 1.0 * _smooth((x - 0.5) / 0.5)
    # 조각·이름("빨간 풍선을", "분홍 리본"): 내리지 않고 살짝 들어 둔다 (뒤에 말이 이어질 수 있게)
    return 1.0 * _smooth(x)


def seoul_voice(y, sr, text, pitch_semitones=PITCH_SEMITONES, formant_ratio=FORMANT_RATIO,
                pitch_range=PITCH_RANGE):
    """한 번의 PSOLA 로 음색(피치 +5, 포먼트 ×1.12)·서울 말투 억양·말끝 늘이기를 함께 한다."""
    import parselmouth
    from parselmouth.praat import call

    f = formant_ratio
    snd = parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr * f)
    man = call(snd, "To Manipulation", 0.01, 75 * f, 600 * f)
    pt = call(man, "Extract pitch tier")
    n = call(pt, "Get number of points")
    if n < 5:
        # 소리가 너무 짧아 억양을 못 잡으면 음색만 바꾼다
        return change_voice(y, sr, pitch_semitones, formant_ratio, pitch_range)
    ts = np.array([call(pt, "Get time from index", i) for i in range(1, n + 1)])
    hz = np.array([call(pt, "Get value at index", i) / f for i in range(1, n + 1)])
    med = float(np.median(hz))
    target = med * 2 ** (pitch_semitones / 12)
    t0, t1 = float(ts[0]), float(ts[-1])
    span = max(1e-3, t1 - t0)
    syl = span / max(1, sum("가" <= c <= "힣" for c in text))
    win0 = t1 - syl * 1.1  # 마지막 음절 자리
    kind = kind_of(text)
    praise = "잘했" in text or "멋져" in text
    decl = DECL if kind != "count" else 0.0

    def body(t):
        pos = (t - t0) / span
        c = decl * ((1 - pos) ** 1.3 - 0.43)  # 높게 시작해 내려온다 (평균 0 근처)
        if praise:
            x = (t - t0) / (syl * 1.4)
            if 0 <= x <= 1:
                c += ACCENT * math.sin(math.pi * x)
        return c

    sts = 12 * np.log2(hz / med) * pitch_range
    fin = ts >= win0
    base = float(np.median(sts[fin][:3])) if fin.any() else 0.0
    newpt = call("Create PitchTier", "p", snd.xmin, snd.xmax)
    for t, st0 in zip(ts, sts):
        st = st0 + body(t)
        if t >= win0:
            # 마지막 음절은 MeloTTS 의 툭 떨어지거나 뾰족하게 튀는 끝 대신 정해 둔 모양으로
            x = (t - win0) / (t1 - win0 + 1e-6)
            a = _smooth(x / 0.25)
            st = (1 - a) * st + a * (base + body(win0) + final_shape(kind, x))
        call(newpt, "Add point", float(t), float(target * 2 ** (st / 12)))
    call([man, newpt], "Replace pitch tier")

    # 길이: f배로 빨라진 것을 되돌리고 마지막 음절만 늘인다
    stretch = STRETCH if kind in ("q", "e") else 1.12
    dt = call("Create DurationTier", "d", snd.xmin, snd.xmax)
    call(dt, "Add point", t0, f)
    call(dt, "Add point", max(t0, win0 - 0.03), f)
    call(dt, "Add point", win0 + 0.04, f * stretch)
    call(dt, "Add point", t1 + 0.05, f * stretch)
    call([man, dt], "Replace duration tier")
    out = call(man, "Get resynthesis (overlap-add)")
    z = np.asarray(out.values[0], dtype=np.float64)
    num, den = 1000, int(round(1000 * f))  # 샘플링 주파수 sr*f → sr
    g = math.gcd(num, den)
    return resample_poly(z, num // g, den // g)


def warm(y, sr):
    """따뜻한 EQ·부드러운 압축 (ffmpeg)"""
    with tempfile.TemporaryDirectory() as d:
        a, b = os.path.join(d, "a.wav"), os.path.join(d, "b.wav")
        import soundfile as sf
        pad = np.zeros(int(0.05 * sr))
        sf.write(a, np.concatenate([pad, y, pad]), sr, subtype="FLOAT")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-af", POST,
                        "-c:a", "pcm_f32le", b], check=True)
        z, _ = sf.read(b)
    return np.asarray(z, dtype=np.float64)


def process(y, sr, text):
    """MeloTTS 결과 → 어린이 느낌 서울 말투 목소리, 말끝 덜 자르기, 따뜻한 EQ, 음량 맞추기"""
    y = gentle_trim(np.asarray(y, dtype=np.float64), sr)
    y = seoul_voice(y, sr, text)
    y = warm(y, sr)
    y = gentle_trim(y, sr)
    return normalize(y, sr)
