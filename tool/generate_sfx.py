#!/usr/bin/env python3
"""알록달록 꼬마 놀이터 효과음 생성기 (v2: 통통 튀는 귀여운 소리).

외부 음원 없이 직접 합성한다 (저작권 문제 없음).
- 날카로운 고음, 버저, 낮고 무거운 소리는 쓰지 않는다.
- 최대 음량을 낮게(-12 dBFS 근처) 유지한다.

사용법: python3 tool/generate_sfx.py  (프로젝트 루트에서 실행)
"""
import math
import os
import struct
import wave

RATE = 22050
PEAK = 0.25
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def tone(f0, dur, f1=None, decay=6.0, harmonics=(1.0, 0.25, 0.08), vibrato=0.0, attack=0.006):
    """f0 → f1로 미끄러지는 둥근 음. 실로폰/버블 느낌."""
    f1 = f1 or f0
    n = int(dur * RATE)
    out, phase = [], 0.0
    a = max(1, int(attack * RATE))
    for i in range(n):
        t = i / RATE
        p = i / n
        f = f0 * (f1 / f0) ** p  # 지수적으로 미끄러짐 (귀에 자연스럽다)
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 7 * t)
        phase += 2 * math.pi * f / RATE
        env = math.exp(-decay * t) * (i / a if i < a else 1)
        out.append(env * sum(h * math.sin(phase * (k + 1)) for k, h in enumerate(harmonics)))
    return out


def mix(parts, total):
    buf = [0.0] * int(total * RATE)
    for start, samples in parts:
        off = int(start * RATE)
        for i, s in enumerate(samples):
            if off + i < len(buf):
                buf[off + i] += s
    peak = max(1e-9, max(abs(x) for x in buf))
    fade = int(0.02 * RATE)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    return [x / peak * PEAK for x in buf]


def save(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print("wrote", os.path.normpath(path), f"{len(samples) / RATE:.2f}s")


C5, D5, E5, F5, G5, A5, C6, D6, E6, G6 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 1046.5, 1174.7, 1318.5, 1568.0
BELL = (1.0, 0.0, 0.35, 0.0, 0.12)  # 홀수 배음: 말랑한 실로폰


def main():
    os.makedirs(OUT, exist_ok=True)
    # 정답: "뾰로롱~" 위로 올라가는 실로폰 + 반짝
    save("correct.wav", mix([
        (0.00, tone(C6, .35, decay=8, harmonics=BELL)),
        (0.08, tone(E6, .35, decay=8, harmonics=BELL)),
        (0.16, tone(G6, .6, decay=5, harmonics=BELL)),
        (0.16, tone(C6 * 2, .5, decay=7, harmonics=(0.25,))),
    ], 0.9))
    # 다시 해 보기: "뿅?" 하고 고개를 갸웃하는 듯한 부드러운 소리 (버저 아님)
    save("try_again.wav", mix([
        (0.00, tone(A5, .18, f1=E5, decay=6, harmonics=(1, .2))),
        (0.20, tone(E5, .28, f1=A5, decay=5, harmonics=(1, .2))),
    ], 0.55))
    # 터치: 비눗방울 "뽁"
    save("tap.wav", mix([(0, tone(G5, .09, f1=C6 * 1.3, decay=28, harmonics=(1, .1)))], .11))
    # 코인: "띠링"
    save("coin.wav", mix([
        (0.00, tone(E6, .12, decay=14, harmonics=BELL)),
        (0.07, tone(G6 * 1.33, .4, decay=8, harmonics=BELL)),
    ], .5))
    # 한 판 완료: 짧고 경쾌한 실로폰 노래
    seq = [(C6, 0), (D6, .12), (E6, .24), (C6, .36), (E6, .5), (G6, .62), (C6 * 2, .8)]
    save("fanfare.wav", mix(
        [(s, tone(f, .45, decay=6, harmonics=BELL)) for f, s in seq]
        + [(.8, tone(G6, .9, decay=3, harmonics=(.3,)))], 1.75))
    # 구매/옷 입기: "샤라랑" 반짝이는 미끄럼
    save("buy.wav", mix(
        [(i * .05, tone(C6 * (1 + i * .12), .3, decay=9, harmonics=BELL)) for i in range(7)]
        + [(0, tone(C5, .6, f1=C6, decay=4, harmonics=(.5, .1)))], .8))
    # 숫자 도장: "쾅!" 통통한 북소리 + 살짝 '톡' (무섭지 않게 중간 높이)
    import random
    rnd = random.Random(7)
    click = [rnd.uniform(-1, 1) * math.exp(-60 * i / RATE) * .5 for i in range(int(.04 * RATE))]
    save("stamp.wav", mix([
        (0.00, click),
        (0.00, tone(260, .22, f1=110, decay=16, harmonics=(1, .35, .1), attack=.002)),
        (0.02, tone(G5, .18, decay=18, harmonics=BELL)),
    ], .3))


if __name__ == "__main__":
    main()
