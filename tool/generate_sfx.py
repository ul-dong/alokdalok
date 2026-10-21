#!/usr/bin/env python3
"""알록달록 꼬마 놀이터 효과음 생성기 (v3: 귀엽고 분명하게, 크기는 고르게).

외부 음원 없이 직접 합성한다 (저작권 문제 없음).
- 날카로운 고음, 버저, 낮고 무거운 소리는 쓰지 않는다.
- 모든 소리는 둥근 어택(클릭 없음)과 부드러운 끝(페이드)으로 만든다.
- 소리마다 들리는 크기(K-가중 순간 음량)를 정해 두고 맞춘다. 최대 음량은 -3 dBFS 아래.
  정답·팡파르(-18)가 가장 크고, 코인·사기(-19), 도장·다시 해 봐요(-21)는 조금 작고 부드럽게,
  자주 나는 누르기 소리(-25)는 가장 작게.
- 짧은 잔향을 살짝 더해 따뜻하게.

사용법: python3 tool/generate_sfx.py  (프로젝트 루트에서 실행, numpy·scipy 필요)
"""
import math
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

RATE = 22050
CEIL = 10 ** (-3 / 20)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")

C5, D5, E5, F5, G5, A5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0
C6, D6, E6, G6, A6, C7, D7 = 1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3
BELL = (1.0, 0.0, 0.3, 0.0, 0.08)  # 홀수 배음: 말랑한 실로폰
ROUND = (1.0, 0.18, 0.05)  # 둥근 피리 같은 소리


def _t(n):
    return np.arange(n) / RATE


def _rise(t, sec):
    x = np.clip(t / max(sec, 1e-4), 0, 1)
    return 0.5 - 0.5 * np.cos(np.pi * x)


def tone(f0, dur, f1=None, decay=6.0, harmonics=(1.0, 0.25, 0.08), vibrato=0.0, attack=0.004):
    """f0 → f1로 미끄러지는 둥근 음. 실로폰/버블 느낌."""
    f1 = f1 or f0
    n = int(dur * RATE)
    t = _t(n)
    p = t / dur
    f = f0 * (f1 / f0) ** p  # 지수적으로 미끄러짐 (귀에 자연스럽다)
    if vibrato:
        f = f * (1 + vibrato * np.sin(2 * np.pi * 6 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    s = np.zeros(n)
    for k, h in enumerate(harmonics):
        if h and max(f0, f1) * (k + 1) < RATE * 0.45:  # 겹침(지글거림) 방지
            s += h * np.sin(phase * (k + 1))
    env = np.exp(-decay * t) * _rise(t, attack)
    env *= np.clip((dur - t) / 0.015, 0, 1)  # 끝도 둥글게
    return s * env


def noise_tap(dur=0.03, cutoff=2500, seed=7):
    n = int(dur * RATE)
    t = _t(n)
    x = np.random.default_rng(seed).uniform(-1, 1, n)
    b, a = butter(2, cutoff / (RATE / 2))
    return lfilter(b, a, x) * _rise(t, 0.0015) * np.exp(-t / (dur / 4))


def room(x, wet=0.12, rt60=0.35, seed=3):
    """작은 방 잔향"""
    n = int(rt60 * RATE)
    t = _t(n)
    ir = np.random.default_rng(seed).standard_normal(n) * np.exp(-6.9 * t / rt60)
    b, a = butter(1, 3000 / (RATE / 2))
    ir = lfilter(b, a, ir)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.convolve(x, ir)[: len(x)]
    return x + wet * y


def momentary_max(x):
    """K-가중 순간 음량(400ms 창)의 최댓값 (LUFS). 짧은 소리의 '들리는 크기'"""
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / RATE)
    vh = 10 ** (g / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / RATE)
    a0 = 1 + k / q + k * k
    a2 = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    blk = int(0.4 * RATE)
    y = lfilter([1, -2, 1], a2, lfilter(b1, a1, np.concatenate([x, np.zeros(blk)])))
    c = np.concatenate([[0], np.cumsum(y ** 2)])
    ms = (c[blk:] - c[:-blk]) / blk
    return -0.691 + 10 * np.log10(np.max(ms) + 1e-12)


def mix(parts, total, loudness, wet=0.12):
    buf = np.zeros(int(total * RATE))
    for start, samples in parts:
        off = int(start * RATE)
        m = min(len(samples), len(buf) - off)
        buf[off:off + m] += samples[:m]
    if wet:
        buf = room(buf, wet)
    t = _t(len(buf))
    buf *= _rise(t, 0.002)  # 첫 샘플부터 0에서 시작 (클릭 없음)
    fade = int(0.03 * RATE)
    buf[-fade:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fade) / fade)
    buf *= 10 ** ((loudness - momentary_max(buf)) / 20)
    peak = np.max(np.abs(buf))
    if peak > CEIL:
        buf *= CEIL / peak
    return buf


def save(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())
    print(f"wrote {os.path.normpath(path)} {len(samples) / RATE:.2f}s "
          f"{momentary_max(samples):.1f} LUFS(M) peak {20 * np.log10(np.max(np.abs(samples))):.1f} dBFS")


def main():
    os.makedirs(OUT, exist_ok=True)
    # 정답: "뾰로롱~" 도-미-솔 위로 올라가는 실로폰 + 아래 옥타브 받침 + 반짝
    save("correct.wav", mix([
        (0.00, tone(C6, .40, decay=8, harmonics=BELL)),
        (0.09, tone(E6, .40, decay=8, harmonics=BELL)),
        (0.18, tone(G6, .65, decay=5, harmonics=BELL)),
        (0.00, tone(C5, .30, decay=10, harmonics=ROUND) * .35),
        (0.09, tone(E5, .30, decay=10, harmonics=ROUND) * .35),
        (0.18, tone(G5, .55, decay=6, harmonics=ROUND) * .35),
        (0.20, tone(C7, .55, decay=7, harmonics=(0.2,))),
    ], 0.95, loudness=-18))
    # 다시 해 보기: "음~ 다시?" 살짝 내려갔다 위로 올라가는 부드러운 소리 (버저·단조 아님)
    save("try_again.wav", mix([
        (0.00, tone(E5, .20, f1=C5, decay=4, harmonics=ROUND, vibrato=.004, attack=.015)),
        (0.22, tone(D5, .32, f1=G5, decay=3, harmonics=ROUND, vibrato=.004, attack=.015)),
    ], 0.62, loudness=-21))
    # 터치: 비눗방울 "뽁" (자주 나므로 가장 작게)
    save("tap.wav", mix([(0, tone(520, .09, f1=820, decay=30, harmonics=(1, .12), attack=.0015))],
                        .11, loudness=-25, wet=0))
    # 코인: "띠링" 미 → 도(높은)
    save("coin.wav", mix([
        (0.00, tone(E6, .14, decay=14, harmonics=BELL)),
        (0.07, tone(C7, .42, decay=8, harmonics=BELL)),
        (0.07, tone(C6, .30, decay=10, harmonics=ROUND) * .25),
    ], .52, loudness=-19))
    # 한 판 완료: 짧고 경쾌한 실로폰 노래 + 밑에 퍼지는 도-미-솔 화음
    seq = [(C6, 0), (D6, .12), (E6, .24), (C6, .36), (E6, .5), (G6, .62), (C7, .8)]
    chord = [(f, .62, tone(f, 1.1, decay=2.5, harmonics=ROUND, attack=.08) * .22) for f in (C5, E5, G5)]
    save("fanfare.wav", mix(
        [(s, tone(f, .45, decay=6, harmonics=BELL)) for f, s in seq]
        + [(s, sig) for _, s, sig in chord]
        + [(.8, tone(G6, .9, decay=3, harmonics=(.25,))),
           (.95, tone(C7 * 1.5, .5, decay=8, harmonics=(.08,)))], 1.75, loudness=-18))
    # 구매/옷 입기: "샤라랑" 반짝이며 올라가는 소리 (5음 음계)
    steps = [C6, D6, E6, G6, A6, C7, D7]
    save("buy.wav", mix(
        [(i * .05, tone(f, .32, decay=9, harmonics=BELL) * (0.7 + 0.05 * i)) for i, f in enumerate(steps)]
        + [(0, tone(C5, .6, f1=C6, decay=4, harmonics=(.5, .1), attack=.03))], .8, loudness=-19))
    # 숫자 도장: "쾅!" 통통한 북소리 + '퐁' (무섭지 않게 중간 높이, 날카로운 잡음 없음)
    save("stamp.wav", mix([
        (0.000, noise_tap(.03, 2200) * .35),
        (0.000, tone(240, .22, f1=120, decay=14, harmonics=(1, .3, .08), attack=.002)),
        (0.015, tone(G5, .2, decay=16, harmonics=BELL) * .6),
    ], .32, loudness=-21, wet=.08))


if __name__ == "__main__":
    main()
