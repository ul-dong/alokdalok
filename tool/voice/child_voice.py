# MeloTTS 원음을 만 3~4세에게 친근한 "만화 캐릭터 느낌" 목소리로 바꾼다. (2026-11 샘플로 고른 목소리)
#   한국어: 샘플 "ko_match_mid"  (높이 약 320Hz, 서울 말투 억양)
#   영어:   샘플 "en_cartoon3"   (장난스러운 톤, 높이 약 390Hz)
# 예전 목소리(피치 +5반음, 포먼트 x1.12)는 "무섭다"는 평을 받았다. 그래서 높이만 올리지 않고
# 포먼트(입 안 울림 자리)는 1.05~1.07 만 올리고, 억양·리듬의 생동감으로 캐릭터 느낌을 낸다.
#
# 방법: Praat(parselmouth, GPL 도구지만 결과 음성에는 아무 조건이 없다)로 한 번의 PSOLA 처리
#   - 높이: 문장마다 원음 중앙값에서 일정하게 올리지 않고 정해 둔 높이(한국어 305Hz)에 맞추거나
#     (영어) 화자 평소 높이 기준으로만 올린다. 원래 들떠서 높게 읽은 문장이 더 높아지지 않게.
#   - 억양: 높은 자리(강세)는 위로 더 튀게(up), 낮은 쪽은 덜(rng). 첫머리를 조금 높게 시작해 내려온다.
#     칭찬은 첫 음절 강세 + 살짝 높게, 감탄은 끝을 크게 올렸다 내리고, 질문은 끝을 부드럽게 올린다.
#     숫자 세기 조각("하나"~"열", "One"~"Ten")은 이어 붙여도 어색하지 않게 약하게만.
#   - 날카롭게 튀지 않게: 원래 높이보다 8반음 위, 절대 천장(한국어 620Hz, 영어 600Hz) 근처는 부드럽게 누른다.
#   - 한국어(방법 2): MeloTTS 로 빠르게(속도 1.1) 만든 뒤 PSOLA 로 1.34배 늘인다.
#     같은 높이에서 그냥 올린 것보다 HNR 이 높고(덜 거칠고) 튀는 곳이 없었다. 말 속도는 약 3.9음절/초.
#   - 억양과 피치·길이를 한 번에 처리해야 금속성 소리가 늘지 않는다.
# 그다음 말끝을 덜 자르고(-55dB, 150ms 남기고 120ms 페이드), 따뜻한 EQ·부드러운 압축을 거쳐,
# 모든 조각을 같은 크기(-16 LUFS, 최대 -1.5 dBFS)로 고정 배율로 맞춘다.
#
# gen_voice.py 가 새 문장을 녹음할 때마다 이 처리를 거치므로, 나중에 추가한 문장도 같은 목소리가 된다.
# 설정을 바꿨다면 그 언어는 --all 로 전부 다시 녹음해야 섞이지 않는다.
import math
import os
import re
import subprocess
import tempfile

import numpy as np
from scipy.signal import lfilter, resample_poly

TARGET_LUFS = -16.0
PEAK_DBFS = -1.5
SILENCE_DB = -45.0  # 앞뒤 무음 자르기 기준 (최대값 대비, 예전 방식 trim)
PAD_SEC = 0.03  # 예전 방식 trim 에서 앞뒤로 남기는 여유
SEED = 1234  # 같은 문장은 늘 같은 녹음이 나오게 (쉰 소리면 RETRY_SEEDS 차례로)

# 말끝 덜 자르기
GENTLE_DB = -55.0
TAIL_SEC = 0.15
TAIL_FADE = 0.12

# 따뜻한 EQ·압축 (ffmpeg): 하이패스 90Hz, 300Hz +2.5dB, 7kHz -3dB, 2:1 압축
POST = ("highpass=f=90:poles=2,"
        "equalizer=f=300:t=q:w=0.9:g=2.5,"
        "equalizer=f=7000:t=q:w=0.8:g=-3,"
        "acompressor=threshold=-20dB:ratio=2:attack=15:release=180:knee=6:makeup=1")

# 언어별 목소리. melo: MeloTTS 설정(화자·속도·sdp_ratio 등), 나머지: 억양 처리
#   target_hz: 이 높이에 맞춘다 (없으면 pitch 반음만큼, 단 화자 평소 높이 ref +2반음까지만 기준으로)
#   fr: 포먼트 비율, rng/up: 낮은 쪽/높은 쪽 억양 폭, acc: 강세(반음), Q: 질문 끝 올림(반음)
#   RF/RFE: 감탄 끝을 올렸다가(RF) 끝은 음절 시작보다 RFE, RFw/RFEw: 약한 감탄(평서)용
#   strx: 마지막 음절 늘이기, lift: 칭찬은 전체를 이만큼 높게, ceil/top: 천장(반음/Hz)
#   tempo: PSOLA 로 길이를 몇 배 늘일지 (빠르게 만든 원음을 늘인다), qslow: 질문은 이만큼 더 천천히
#   melo.q_speed: 질문 문장은 MeloTTS 에서부터 이 속도로 천천히 만든다
#   ap: 한국어 어절마다 넣는 약한 억양 굽이(반음). 말끝만 올라가지 않고 문장 전체가 고르게 움직이게
#   (2026-11-15 수정: 튐·전자음 깨짐 때문에 억양 확대·높이·포먼트를 줄이고, 옥타브 오류 보정·
#    무성음 구간 보호·곡선 다듬기·변화 속도 제한을 넣었다. 질문은 천천히)
VOICES = {
    "KR": dict(
        melo=dict(speaker="KR", speed=1.1, q_speed=0.95, sdp_ratio=0.8, noise_scale=0.7, noise_scale_w=1.0),
        ref=190.0, target_hz=300.0, pitch=0.0, fr=1.06, rng=1.15, up=1.3, acc=2.0, decl=1.5,
        ap=2.6, Q=5.5, RF=3.5, RFE=-1.0, RFw=2.0, RFEw=-0.3, strx=1.2, lift=0.7,
        ceil=6.0, top=520.0, tempo=1.34, qslow=1.38),
    "EN": dict(
        melo=dict(speaker="EN-US", speed=0.92, q_speed=0.68, sdp_ratio=0.8, noise_scale=0.7, noise_scale_w=1.0),
        ref=295.0, target_hz=None, pitch=2.0, fr=1.03, rng=1.15, up=1.3, acc=1.8, decl=1.0,
        ap=0.0, Q=6.0, RF=3.5, RFE=-1.0, RFw=2.0, RFEw=-0.3, strx=1.2, lift=0.7,
        ceil=6.0, top=540.0, tempo=1.0, qslow=1.6),
}
# 예전 이름: 한국어 MeloTTS 설정
MELO = {k: v for k, v in VOICES["KR"]["melo"].items() if k not in ("speaker", "q_speed")}


def melo_speed(text, lang="KR"):
    """MeloTTS 속도. 질문은 처음부터 천천히 만든다 (PSOLA 로 많이 늘이면 소리가 거칠어진다).
    만 3세가 따라오게 질문 말 속도는 3.2음절/초 이하가 목표."""
    m = VOICES[lang]["melo"]
    return m["q_speed"] if text.strip().endswith("?") else m["speed"]

# 숫자 세기 조각: 도장 박자에 맞춰 한 마디씩 이어 말하므로 억양을 약하게
COUNTING = {"하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉", "열",
            "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"}
PRAISE_EN = re.compile(r"\b(great|good|cool|yay|wow|well done|super|awesome|amazing)\b", re.I)


def change_voice(y, sr, pitch_semitones, formant_ratio, pitch_range):
    """Praat Change gender (아주 짧은 소리용). 원래 피치 중앙값보다 pitch_semitones 만큼 높게 맞춘다."""
    import parselmouth
    from parselmouth.praat import call

    snd = parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr)
    pitch = call(snd, "To Pitch", 0.0, 75, 600)
    median = call(pitch, "Get quantile", 0, 0, 0.5, "Hertz")
    if not median or math.isnan(median):
        median = 210.0  # 소리가 너무 짧아 피치를 못 잰 경우
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


def syllables(text, lang):
    """음절 수 (한국어: 한글 글자 수, 영어: 모음 묶음 수로 어림)"""
    if lang == "KR":
        return max(1, sum("가" <= c <= "힣" for c in text))
    n = 0
    for w in re.findall(r"[A-Za-z']+", text):
        w = w.lower()
        if w.endswith("e") and len(w) > 2:
            w = w[:-1]
        n += max(1, len(re.findall(r"[aeiouy]+", w)))
    return max(1, n)


def kind_of(text, lang="KR"):
    """끝 억양 종류: q(질문) praise(칭찬) e(감탄·평서) count(숫자 세기) name(문장 조각·이름)"""
    t = text.strip()
    if t in COUNTING:
        return "count"
    if t.endswith("?"):
        return "q"
    if lang != "KR" and PRAISE_EN.search(t):
        return "praise"
    if t[-1:] in "!.":
        return "praise" if ("잘했" in t or "멋져" in t) else "e"
    return "name"


def _smooth(x):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, x)))


def final_shape(kind, x, q, rf, rfe):
    """마지막 음절 모양 (음절 시작 높이 기준, 반음). x: 0~1"""
    if kind == "q":  # 부드럽게 올린다
        return q * _smooth(x)
    if kind in ("e", "praise"):  # 올렸다가 내린다
        if x < 0.4:
            return rf * _smooth(x / 0.4)
        return rf + (rfe - rf) * _smooth((x - 0.4) / 0.6)
    if kind == "count":  # "하나~": 아주 살짝 올렸다가 제자리 (이어 세어도 자연스럽게)
        if x < 0.5:
            return 1.2 * _smooth(x / 0.5)
        return 1.2 - 1.0 * _smooth((x - 0.5) / 0.5)
    # 조각·이름("빨간 풍선을"): 내리지 않고 살짝 들어 둔다 (뒤에 말이 이어질 수 있게)
    return 1.0 * _smooth(x)


def _fix_octaves(ts, hz):
    """피치 추정의 옥타브 오류(앞뒤 80ms 값보다 2배·반으로 뛴 점)를 제자리로 접는다"""
    hz = hz.copy()
    for i in range(len(hz)):
        near = hz[(np.abs(ts - ts[i]) <= 0.08) & (np.arange(len(hz)) != i)]
        if len(near) < 2:
            continue
        ref = float(np.median(near))
        while hz[i] > ref * 1.6:
            hz[i] /= 2
        while hz[i] < ref / 1.6:
            hz[i] *= 2
    return hz


def _tidy(ts, st, win=0.05, max_step=1.2):
    """곡선 다듬기: 이어진 유성음 구간 안에서만 50ms 평균, 10ms 에 1.2반음 넘게 바뀌지 않게"""
    st = np.asarray(st, dtype=np.float64).copy()
    seg = np.concatenate([[0], np.cumsum(np.diff(ts) > 0.025)])  # 25ms 넘게 비면 다른 구간
    out = st.copy()
    for g in np.unique(seg):
        idx = np.where(seg == g)[0]
        for i in idx:
            m = idx[np.abs(ts[idx] - ts[i]) <= win / 2]
            out[i] = np.mean(st[m])
        for _ in range(2):  # 앞으로·뒤로 변화 속도 제한
            for a, b in zip(idx[:-1], idx[1:]):
                lim = max_step * max(1.0, (ts[b] - ts[a]) / 0.01)
                out[b] = min(max(out[b], out[a] - lim), out[a] + lim)
            for a, b in zip(idx[::-1][:-1], idx[::-1][1:]):
                lim = max_step * max(1.0, (ts[a] - ts[b]) / 0.01)
                out[b] = min(max(out[b], out[a] - lim), out[a] + lim)
    return out


def cartoon_voice(y, sr, text, lang="KR", v=None):
    """한 번의 PSOLA 로 음색(높이·포먼트)·억양·말끝 늘이기·길이를 함께 한다."""
    import parselmouth
    from parselmouth.praat import call

    v = v or VOICES[lang]
    f = v["fr"]
    snd = parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr * f)
    man = call(snd, "To Manipulation", 0.01, 75 * f, 700 * f)
    pt = call(man, "Extract pitch tier")
    n = call(pt, "Get number of points")
    k = kind_of(text, lang)
    if n < 5:
        # 소리가 너무 짧아 억양을 못 잡으면 음색만 바꾼다
        st = v["pitch"] if not v["target_hz"] else 12 * math.log2(v["target_hz"] / v["ref"])
        return change_voice(y, sr, st, f, v["rng"])
    ts = np.array([call(pt, "Get time from index", i) for i in range(1, n + 1)])
    hz = _fix_octaves(ts, np.array([call(pt, "Get value at index", i) / f for i in range(1, n + 1)]))
    med = float(np.median(hz))
    lift = v["lift"] if k == "praise" else 0.0
    if v["target_hz"]:
        target = v["target_hz"] * 2 ** (lift / 12)
    else:
        target = min(med, v["ref"] * 2 ** (2 / 12)) * 2 ** ((v["pitch"] + lift) / 12)
    strong = k in ("e", "praise")  # 강한 튐은 감탄·칭찬에만
    t0, t1 = float(ts[0]), float(ts[-1])
    span = max(1e-3, t1 - t0)
    syl = span / syllables(text, lang)
    win0 = t1 - syl * 1.1  # 마지막 음절 자리
    decl = 0.0 if k == "count" else v["decl"]
    up = v["up"] if strong else v["rng"]

    def body(t):
        c = decl * ((1 - (t - t0) / span) ** 1.3 - 0.43)  # 높게 시작해 내려온다 (평균 0 근처)
        if strong:
            x = (t - t0) / (syl * 1.4)
            if 0 <= x <= 1:
                c += v["acc"] * math.sin(math.pi * x)
        return c

    top = v["top"]

    def lim(st):
        """날카롭게 튀지 않게: target 위 ceil 반음, 절대 천장 top 근처를 부드럽게 누른다"""
        c = v["ceil"]
        if st > c - 3:
            st = c - 3 + 3 * math.tanh((st - (c - 3)) / 3)
        h = target * 2 ** (st / 12)
        c2 = top / 1.19  # 천장 3반음 아래부터
        if h > c2:
            h = c2 * 2 ** (3 * math.tanh(12 * math.log2(h / c2) / 3) / 12)
        return 12 * math.log2(h / target)

    # 한국어 어절 굽이: 어절마다 낮게 시작해 가운데쯤 올랐다 내려온다 (서울 말투, 약하게)
    words = []
    if v["ap"] and lang == "KR":
        counts = [syllables(w, lang) for w in text.split()]
        tot = max(1, sum(counts))
        acc_t = t0
        for c in counts[:-1]:  # 마지막 어절은 말끝 모양이 맡는다
            dur = span * c / tot
            words.append((acc_t, acc_t + dur))
            acc_t += dur

    def phrase(t):
        c = 0.0
        for j, (a0, a1) in enumerate(words):
            if a0 <= t <= a1:
                x = (t - a0) / max(1e-3, a1 - a0)
                c += v["ap"] * (1.25 if j == 0 else 1.0) * math.sin(math.pi * x) ** 2
        return c

    # 각 점이 얼마나 "또렷한 유성음"인지 (0~1). 무성음(s, z, ch)·약한 소리 쪽은 원래 높이 모양을 지킨다
    inten = call(snd, "To Intensity", 100, 0, "yes")
    imax = call(inten, "Get maximum", 0, 0, "Parabolic")
    harm = call(snd, "To Harmonicity (cc)", 0.01, 75 * f, 0.1, 1.0)
    w = np.empty(n)
    for i, t in enumerate(ts):
        iv = call(inten, "Get value at time", float(t), "Cubic")
        hv = call(harm, "Get value at time", float(t), "Cubic")
        iv = imax - 60 if iv is None or math.isnan(iv) else iv
        hv = -10 if hv is None or math.isnan(hv) else hv
        w[i] = max(0.0, min(1.0, (iv - (imax - 28)) / 10)) * max(0.0, min(1.0, (hv - 1.0) / 6))

    st0 = 12 * np.log2(hz / med)
    sts = np.where(st0 > 0, st0 * up, st0 * v["rng"])  # 강세는 위로 더, 낮은 쪽은 덜
    fin = ts >= win0
    base = float(np.median(sts[fin][:3])) if fin.any() else 0.0
    if strong:
        base = max(base, -1.0)  # 감탄 말끝이 바닥에서 시작하지 않게
    rf, rfe = (v["RF"], v["RFE"]) if strong else (v["RFw"], v["RFEw"])
    shaped = np.empty(n)
    for i, (t, s0) in enumerate(zip(ts, sts)):
        st = s0 + body(t) + phrase(t)
        if t >= win0:
            # 마지막 음절은 MeloTTS 의 툭 떨어지거나 뾰족하게 튀는 끝 대신 정해 둔 모양으로
            x = (t - win0) / (t1 - win0 + 1e-6)
            a = _smooth(x / (0.25 if k == "q" else 0.4))
            st = (1 - a) * st + a * (base + body(win0) + final_shape(k, x, v["Q"], rf, rfe))
        shaped[i] = st
    # 약한 소리(z, 말끝 숨소리 등)는 억양 확대를 하지 않고, 가까운 또렷한 모음의 높이를 이어 받는다.
    # (원래 낮은 높이로 두면 "apples" 의 -s 처럼 모음 뒤에서 뚝 떨어져 튀게 들린다)
    strong_i = np.where(w >= 0.6)[0]
    out_st = np.empty(n)
    for i in range(n):
        if w[i] >= 0.999 or len(strong_i) == 0:
            out_st[i] = shaped[i] if len(strong_i) else st0[i]
            continue
        j = strong_i[np.argmin(np.abs(ts[strong_i] - ts[i]))]
        anchor = shaped[j]  # 말끝을 늘인 -s/-z 처럼 모음에서 멀어도 모음 높이를 잇는다
        out_st[i] = w[i] * shaped[i] + (1 - w[i]) * anchor
    out_st = _tidy(ts, out_st)
    newpt = call("Create PitchTier", "p", snd.xmin, snd.xmax)
    for t, st in zip(ts, out_st):
        call(newpt, "Add point", float(t), float(target * 2 ** (lim(st) / 12)))
    call([man, newpt], "Replace pitch tier")

    # 길이: f배로 빨라진 것을 되돌리고(×tempo 만큼 더 늘이고) 마지막 음절만 더 늘인다
    stretch = v["strx"] if k in ("q", "e", "praise") else 1.1
    d = f * v["tempo"] * (v["qslow"] if k == "q" else 1.0)
    dt = call("Create DurationTier", "d", snd.xmin, snd.xmax)
    call(dt, "Add point", t0, d)
    call(dt, "Add point", max(t0, win0 - 0.03), d)
    call(dt, "Add point", win0 + 0.04, d * stretch)
    call(dt, "Add point", t1 + 0.05, d * stretch)
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


def jumps(y, sr, semitones=5.0):
    """20ms 안에 음높이가 semitones 반음 넘게 뛰는 곳의 수 (튀는 소리 점검).
    점검 기준은 6반음이지만 mp3 로 바꾸며 조금 달라지므로 5반음으로 여유 있게 잰다."""
    import parselmouth
    from parselmouth.praat import call

    fr = call(parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr),
              "To Pitch", 0.01, 75, 800).selected_array["frequency"]
    a, b = fr[:-2], fr[2:]
    ok = (a > 0) & (b > 0)
    return int(np.sum(np.abs(12 * np.log2(b[ok] / a[ok])) > semitones))


# 튀는 곳이 남으면 차례로 더 순하게 다시 만든다 (억양 확대 없이 → 높이만)
SAFER = [
    dict(rng=1.0, up=1.0, acc=0.8, ap=1.0, Q=4.0, RF=2.0, RFE=-0.5, ceil=5.0),
    dict(rng=1.0, up=1.0, acc=0.0, ap=0.0, Q=2.5, RF=1.0, RFE=0.0, RFw=1.0, ceil=4.0, decl=0.5),
]
MAX_JUMPS = 1  # 이보다 많으면 순한 설정으로 다시
RETRY_SEEDS = [1, 2, 3, 4, 5]  # gen_voice.py: 소리가 쉬면(HNR < HNR_GOAL) 이 씨앗들로 다시 만들어 본다
HNR_GOAL = 14.5


def hnr(y, sr):
    """소리의 맑기(HNR, dB). 높을수록 쉰 소리·잡음이 적다"""
    import parselmouth
    from parselmouth.praat import call

    s = parselmouth.Sound(np.asarray(y, dtype=np.float64), sampling_frequency=sr)
    return float(call(call(s, "To Harmonicity (cc)", 0.01, 75, 0.1, 1.0), "Get mean", 0, 0))


def process(y, sr, text, lang="KR"):
    """MeloTTS 결과 → 만화 캐릭터 느낌 목소리, 말끝 덜 자르기, 따뜻한 EQ, 음량 맞추기"""
    y = gentle_trim(np.asarray(y, dtype=np.float64), sr)
    v = dict(VOICES[lang])
    z = cartoon_voice(y, sr, text, lang, v)
    for safer in SAFER:
        if jumps(z, sr) <= MAX_JUMPS:
            break
        v.update(safer)
        z = cartoon_voice(y, sr, text, lang, v)
    z = warm(z, sr)
    z = gentle_trim(z, sr)
    return normalize(z, sr)
