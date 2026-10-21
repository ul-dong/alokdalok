"""계절 배경 음악 4곡을 직접 작곡·합성한다 (외부 음원·샘플 없음, 저작권 걱정 없음).

python3 tool/generate_music.py  → assets/audio/music/{spring,summer,autumn,winter,home,shop}.mp3

- 봄: 실로폰(마림바) + 통통 튀는 베이스, C장조 120BPM
- 여름: 스틸드럼 + 셰이커, F장조 128BPM, 엇박 리듬
- 가을: 기타 뜯는 소리 + 부드러운 베이스, G장조 104BPM, 살짝 흔들리는 박자
- 겨울: 첼레스타(종소리) + 썰매 방울, D장조 116BPM
각 곡은 16마디가 끊김 없이 반복되도록 만든다 (끝의 울림을 앞에 겹쳐 넣음).
"""

import math
import os
import random
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------- 악기 ----------------

def env(n, attack=0.005, decay=0.4):
    t = np.arange(n) / SR
    a = np.minimum(1, t / max(attack, 1e-4))
    return a * np.exp(-t / decay)


def marimba(f, dur):
    n = int(SR * (dur + 0.6))
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.35)
         + 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.05)
         + 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.02))
    return s * np.minimum(1, t / 0.002)


def steel(f, dur):
    n = int(SR * (dur + 0.7))
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.5)
         + 0.5 * np.sin(2 * np.pi * f * 2.0 * t + 0.3) * np.exp(-t / 0.25)
         + 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.12)
         + 0.1 * np.sin(2 * np.pi * f * 4.2 * t) * np.exp(-t / 0.06))
    return s * np.minimum(1, t / 0.004)


def pluck(f, dur, rng):
    # Karplus-Strong 기타
    n = int(SR * (dur + 0.8))
    p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
    t = np.arange(n) / SR
    return out * np.exp(-t / 0.9)


def celesta(f, dur):
    n = int(SR * (dur + 0.9))
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.6)
         + 0.4 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.3)
         + 0.2 * np.sin(2 * np.pi * f * 4.01 * t) * np.exp(-t / 0.12))
    return s * np.minimum(1, t / 0.003)


def bass(f, dur):
    n = int(SR * (dur + 0.05))
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t)
    e = np.minimum(1, t / 0.01) * np.exp(-t / max(0.12, dur * 0.8))
    return s * e


def soft_chord(fs, dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t) for f in fs)
    e = np.minimum(1, t / 0.15) * np.minimum(1, (dur - t) / 0.2).clip(0, 1)
    return s * e / len(fs)


def kick():
    n = int(SR * 0.25)
    t = np.arange(n) / SR
    f = 110 * np.exp(-t / 0.04) + 45
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.09)


def noise_hit(rng, dur, decay, hp=True):
    n = int(SR * dur)
    x = rng.uniform(-1, 1, n)
    if hp:
        x = np.diff(np.concatenate([[0], x]))  # 고음만 남기기
    t = np.arange(n) / SR
    return x * np.exp(-t / decay)


def jingle(rng):
    # 썰매 방울: 짧은 금속성 소리 몇 개
    n = int(SR * 0.25)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for _ in range(4):
        f = rng.uniform(4500, 7500)
        d = rng.uniform(0, 0.03)
        tt = np.clip(t - d, 0, None)
        s += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.05) * (t > d)
    return s * 0.3


# ---------------- 작곡 ----------------

SCALE = [0, 2, 4, 5, 7, 9, 11]


def chord_tones(root_deg):
    return [SCALE[(root_deg + k) % 7] + 12 * ((root_deg + k) // 7) for k in (0, 2, 4)]


def compose(seed, key, prog, rhythms, octave=72):
    """16마디 멜로디: A(4) A'(4) B(4) A''(4). 강박은 화음음, 약박은 음계 이웃음."""
    rng = random.Random(seed)
    tonic = NOTE[key]

    def bar_melody(chord_deg, rhythm, prev):
        notes = []
        tones = chord_tones(chord_deg)
        pos = 0
        for i, d in enumerate(rhythm):
            strong = pos % 4 == 0
            if strong or rng.random() < 0.55:
                cand = [t + o for t in tones for o in (0, 12, -12)]
            else:
                cand = [s + o for s in SCALE for o in (0, 12, -12)]
            cand = [c for c in cand if -3 <= c <= 16]
            # 앞 음과 가까운 음 위주 (노래하듯 매끄럽게)
            cand.sort(key=lambda c: abs(c - prev) + rng.random() * 3)
            c = cand[0] if rng.random() < 0.7 else cand[min(1, len(cand) - 1)]
            if c == prev and rng.random() < 0.6 and len(cand) > 1:
                c = cand[1]
            notes.append((c, d))
            prev = c
            pos += d
        return notes, prev

    phrase_a, prev = [], 4
    for b in range(4):
        m, prev = bar_melody(prog[b], rhythms[b % len(rhythms)], prev)
        phrase_a.append(m)
    phrase_b, prev2 = [], 7
    for b in range(4):
        m, prev2 = bar_melody(prog[4 + b], rhythms[(b + 2) % len(rhythms)], prev2)
        phrase_b.append(m)

    def end_on_tonic(bar):
        bar = list(bar)
        c, d = bar[-1]
        bar[-1] = (0 if abs(c) < abs(c - 12) else 12, d)
        return bar

    a2 = phrase_a[:3] + [end_on_tonic(phrase_a[3])]
    a3 = phrase_a[:2] + [phrase_b[2], end_on_tonic(phrase_a[3])]
    bars = phrase_a + a2 + phrase_b + a3
    return [[(octave + tonic + c, d) for c, d in bar] for bar in bars]


# ---------------- 곡 만들기 ----------------

def render(name, *, key, bpm, prog, rhythms, lead, seed, swing=0.0,
           drums="pop", arp=True, gain_lead=0.5):
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    eighth = beat / 2
    bars = 16
    bar_len = beat * 4
    total = int(SR * bar_len * bars)
    mix = np.zeros(total + SR * 2)
    pyr = random.Random(seed)

    def put(sig, t, g):
        i = int(t * SR)
        mix[i:i + len(sig)] += sig[: max(0, len(mix) - i)] * g

    def when(slot):  # 8분음표 위치 → 초 (스윙)
        t = slot * eighth
        if swing and slot % 2 == 1:
            t += eighth * swing
        return t

    melody = compose(seed, key, prog * 2, rhythms)
    tonic = NOTE[key]
    for b in range(bars):
        t0 = b * bar_len
        deg = (prog * 2)[b]
        tones = chord_tones(deg)
        root = 48 + tonic + tones[0]
        # 화음 바탕 (아주 작게)
        put(soft_chord([hz(60 + tonic + x) for x in tones], bar_len), t0, 0.07)
        # 베이스: 근음-5음 통통
        for k, (iv, d) in enumerate([(0, 2), (7, 2), (0, 2), (7, 2)]):
            put(bass(hz(root - 12 + iv), eighth * d * 0.9), t0 + k * beat, 0.32)
        # 분산 화음 (16분음표처럼 반짝)
        if arp:
            pat = [0, 1, 2, 1, 0, 2, 1, 2]
            for k, p in enumerate(pat):
                f = hz(72 + tonic + tones[p] + (12 if k % 4 == 3 else 0))
                sig = celesta(f, eighth) if lead is not celesta else marimba(f, eighth)
                put(sig, t0 + when(k), 0.06)
        # 멜로디
        slot = 0
        for m, d in melody[b]:
            f = hz(m)
            sig = lead(f, eighth * d, rng) if lead is pluck else lead(f, eighth * d)
            put(sig, t0 + when(slot), gain_lead)
            slot += d
        # 타악기
        for k in range(8):
            t = t0 + when(k)
            if drums in ("pop", "island") and k in (0, 4):
                put(kick(), t, 0.45)
            if drums == "pop":
                put(noise_hit(rng, 0.05, 0.012), t, 0.05 if k % 2 else 0.08)
                if k in (2, 6):
                    put(noise_hit(rng, 0.15, 0.05, hp=False), t, 0.06)  # 손뼉
            elif drums == "island":
                put(noise_hit(rng, 0.08, 0.02), t, 0.07)  # 셰이커
                if k in (3, 6):
                    put(noise_hit(rng, 0.12, 0.04, hp=False), t, 0.05)
            elif drums == "soft":
                if k in (0, 4):
                    put(kick(), t, 0.25)
                if k in (2, 6):
                    put(noise_hit(rng, 0.06, 0.02), t, 0.05)
            elif drums == "jingle":
                if k in (0, 4):
                    put(kick(), t, 0.3)
                put(jingle(rng), t, 0.5 if k % 2 == 0 else 0.3)
        _ = pyr

    # 끝의 울림을 앞에 겹쳐 자연스럽게 반복
    tail = mix[total:]
    mix = mix[:total]
    mix[: len(tail)] += tail
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.8

    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, f"{name}.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())
    mp3 = os.path.join(OUT, f"{name}.mp3")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
         "-af", "loudnorm=I=-19:TP=-2:LRA=9", "-ar", "44100", "-ac", "1",
         "-b:a", "80k", mp3],
        check=True,
    )
    os.remove(wav)
    print(name, f"{total / SR:.1f}s", os.path.getsize(mp3) // 1024, "KB")


if __name__ == "__main__":
    # 리듬: 8분음표 단위 길이 목록 (한 마디 = 8)
    bouncy = [[1, 1, 2, 1, 1, 2], [2, 1, 1, 2, 2], [1, 1, 1, 1, 2, 2], [2, 2, 1, 1, 2]]
    island = [[1, 2, 1, 2, 2], [2, 1, 2, 1, 2], [1, 1, 2, 2, 2], [3, 1, 2, 2]]
    gentle = [[2, 2, 2, 2], [3, 1, 2, 2], [2, 1, 1, 4], [2, 2, 4]]
    jingly = [[2, 2, 2, 2], [1, 1, 2, 2, 2], [2, 2, 1, 1, 2], [2, 2, 4]]
    # 화음 진행 (음계 도수: 0=I 3=IV 4=V 5=vi 1=ii)
    render("spring", key="C", bpm=120, prog=[0, 4, 5, 3, 0, 4, 3, 4],
           rhythms=bouncy, lead=marimba, seed=11, drums="pop")
    render("summer", key="F", bpm=128, prog=[0, 3, 4, 0, 5, 3, 1, 4],
           rhythms=island, lead=steel, seed=23, drums="island")
    render("autumn", key="G", bpm=104, prog=[0, 5, 3, 4, 0, 5, 1, 4],
           rhythms=gentle, lead=pluck, seed=37, swing=0.33, drums="soft",
           gain_lead=0.7)
    render("winter", key="D", bpm=116, prog=[0, 3, 0, 4, 5, 3, 1, 4],
           rhythms=jingly, lead=celesta, seed=41, drums="jingle")
    # 대기화면·상점: 같은 실로폰 계열 음색으로 조금 더 차분하게
    render("home", key="F", bpm=108, prog=[0, 5, 3, 4, 0, 5, 3, 4],
           rhythms=gentle, lead=marimba, seed=53, drums="soft")
    render("shop", key="G", bpm=124, prog=[0, 3, 4, 0, 5, 1, 4, 0],
           rhythms=bouncy, lead=celesta, seed=67, drums="pop")
