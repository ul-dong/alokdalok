# 어른 목소리(MeloTTS 한국어 화자)를 만 3세에게 친근한 "어린이 느낌" 목소리로 바꾼다.
#
# 방법: Praat(parselmouth, GPL 도구지만 결과 음성에는 아무 조건이 없다)의 "Change gender"
#   - 목소리 높이(피치) 중앙값을 약 +5 반음 올리고 (어른 여성 ~210Hz → ~280Hz)
#   - 포먼트(입 안 울림 자리)는 +2 반음 정도만 올린다 (×1.12). 피치만큼 다 올리면 다람쥐 소리가 난다.
#   - 억양 폭을 조금 넓혀 (×1.15) 동화책 읽어 주듯 밝게
#   - PSOLA 방식이라 말 속도는 그대로다 (속도는 MeloTTS speed 로 정한다)
# 그다음 앞뒤 무음을 자르고, 모든 조각을 같은 크기(-16 LUFS, 최대 -1.5 dBFS)로 고정 배율로 맞춘다.
#
# gen_voice.py 가 새 문장을 녹음할 때마다 이 처리를 거치므로, 나중에 추가한 문장도 같은 목소리가 된다.
import math

import numpy as np
from scipy.signal import lfilter

# 다른 사람이 바꿔 볼 수 있게 숫자를 한곳에 모았다
PITCH_SEMITONES = 5.0  # 원래 목소리 중앙값에서 몇 반음 올릴지
FORMANT_RATIO = 1.12  # 포먼트 이동 비율 (1.0 = 그대로, 1.2 이상은 다람쥐 소리 위험)
PITCH_RANGE = 1.15  # 억양 폭
TARGET_LUFS = -16.0
PEAK_DBFS = -1.5
SILENCE_DB = -45.0  # 앞뒤 무음 자르기 기준 (최대값 대비)
PAD_SEC = 0.03  # 자른 뒤 앞뒤로 남기는 여유


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


def process(y, sr):
    """MeloTTS 결과 → 어린이 느낌 목소리, 무음 자르기, 음량 맞추기"""
    y = trim(np.asarray(y, dtype=np.float64), sr)
    y = change_voice(y, sr)
    y = trim(y, sr)
    return normalize(y, sr)
