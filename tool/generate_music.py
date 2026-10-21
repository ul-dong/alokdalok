"""배경 음악 6곡을 직접 작곡·합성한다 (외부 음원·샘플 없음, 저작권 걱정 없음).

python3 tool/generate_music.py  → assets/audio/music/{spring,summer,autumn,winter,home,shop}.mp3
(numpy, scipy, ffmpeg 필요)

멜로디는 첫 버전(사용자가 고른 곡)과 같은 음·같은 리듬이다. compose()는 바꾸지 않는다.
v2에서 다듬은 것:
- 층 나누기: 베이스(현 피치카토) · 화음 패드(부드러운 현악) · 분산 화음 · 멜로디 · 아주 작은 타악기
- 화성: 음끼리 가깝게 이어지는 자리바꿈, ii·V에는 7음을 살짝 더해 클래식풍으로
- 음색: 부드러운 말렛 어택, 높은 배음을 줄이고, 짧은 잔향(공간감)을 원형으로 걸어 반복 이음매가 없다
- 이음매: 끝에서 넘친 울림·잔향을 처음에 겹치고, 볼륨을 시간에 따라 바꾸는 처리를 쓰지 않는다
- 음량: 모든 곡을 같은 크기(-20 LUFS)로 맞춘다. 앱에서는 이보다 더 작게(약 0.3배) 틀어 목소리가 잘 들린다
- 템포: 유아가 편하게 듣도록 조금 느리게
- 계절 특징: 봄=밝은 실로폰과 새소리, 여름=스틸드럼과 통통 튀는 리듬,
  가을=기타와 따뜻한 낮은 현, 겨울=첼레스타와 종소리·썰매 방울
"""

import math
import os
import random
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
LUFS_TARGET = -20.0
MP3_QUALITY = "4"  # 모노 VBR(평균 약 70kbps). 곡이 조금 길어져도 전체 용량은 예전(80k 고정)보다 작다
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def _t(n):
    return np.arange(n) / SR


def _attack(t, sec):
    """끝이 둥근 어택 (클릭 없음)"""
    x = np.clip(t / max(sec, 1e-4), 0, 1)
    return 0.5 - 0.5 * np.cos(np.pi * x)


def _partial(f, ratio, t):
    """나이퀴스트 근처 배음은 빼서 지글거림을 막는다"""
    if f * ratio > 15000:
        return 0.0
    return np.sin(2 * np.pi * f * ratio * t)


# ---------------- 악기 ----------------

def marimba(f, dur, vel=1.0):
    n = int(SR * (dur + 1.0))
    t = _t(n)
    dec = float(np.clip(0.55 * (262 / f) ** 0.5, 0.2, 0.9))
    s = (_partial(f, 1, t) * np.exp(-t / dec)
         + 0.16 * vel * _partial(f, 3.93, t) * np.exp(-t / (dec * 0.16))
         + 0.03 * vel * _partial(f, 9.2, t) * np.exp(-t / 0.012)
         + 0.08 * _partial(f, 2, t) * np.exp(-t / (dec * 0.5)))
    return s * _attack(t, 0.003)


def steel(f, dur, vel=1.0):
    n = int(SR * (dur + 1.0))
    t = _t(n)
    s = (_partial(f, 1, t) * np.exp(-t / 0.55)
         + 0.38 * _partial(f, 2.0, t + 0.0003) * np.exp(-t / 0.3)
         + 0.12 * vel * _partial(f, 3.01, t) * np.exp(-t / 0.13)
         + 0.03 * vel * _partial(f, 4.2, t) * np.exp(-t / 0.05))
    return s * _attack(t, 0.005)


def pluck(f, dur, rng, vel=1.0):
    """Karplus-Strong 나일론 기타 (부드러운 손가락 튕김)"""
    n = int(SR * (dur + 1.2))
    d = SR / f - 1.0  # 고리 필터의 1샘플 지연은 빼고
    p = int(d)
    frac = d - p
    if frac < 0.1:
        p, frac = p - 1, frac + 1
    c = (1 - frac) / (1 + frac)  # 남은 소수 지연은 전역 통과 필터로 (정확한 음정)
    exc = rng.uniform(-1, 1, p * 2)
    b, a = butter(2, min(0.45, 1800 / (SR / 2)))  # 저역 통과: 손끝으로 튕긴 둥근 소리
    exc = lfilter(b, a, exc)[p:]
    exc -= exc.mean()
    x = np.zeros(n)
    x[:p] = exc
    g = 0.996
    # 고리: 1 - g·L(z)·A(z)·z^-p, L = [.25 .5 .25] (높은 소리가 빨리 사라짐), A = (c + z^-1)/(1 + c·z^-1)
    loop = np.convolve([0.25, 0.5, 0.25], [c, 1.0]) * g
    a = np.zeros(p + len(loop))
    a[0], a[1] = 1.0, c
    a[p:] -= loop
    y = lfilter([1.0, c], a, x)
    t = _t(n)
    y *= np.exp(-t / 1.1) * _attack(t, 0.007)
    return y / (np.max(np.abs(y)) + 1e-9) * (0.85 + 0.15 * vel)


def celesta(f, dur, vel=1.0):
    n = int(SR * (dur + 1.2))
    t = _t(n)
    s = (_partial(f, 1, t) * np.exp(-t / 0.75)
         + 0.22 * _partial(f, 2, t) * np.exp(-t / 0.35)
         + 0.09 * vel * _partial(f, 4.01, t) * np.exp(-t / 0.12)
         + 0.03 * vel * _partial(f, 6.0, t) * np.exp(-t / 0.04))
    # 아주 살짝 어긋난 두 번째 음: 반짝이는 맥놀이
    s += 0.18 * _partial(f * 1.0025, 1, t) * np.exp(-t / 0.6)
    return s * _attack(t, 0.002)


def chime(f):
    """겨울 종소리 (튜블러 벨처럼 길게, 그러나 작게)"""
    n = int(SR * 3.0)
    t = _t(n)
    s = (_partial(f, 1, t) * np.exp(-t / 1.6)
         + 0.5 * _partial(f, 2.0, t) * np.exp(-t / 1.0)
         + 0.25 * _partial(f, 3.0, t) * np.exp(-t / 0.5)
         + 0.12 * _partial(f, 4.2, t) * np.exp(-t / 0.25))
    return s * _attack(t, 0.004)


def harp(f, dur, vel=1.0):
    n = int(SR * (dur + 1.2))
    t = _t(n)
    s = (_partial(f, 1, t) * np.exp(-t / 0.9)
         + 0.3 * _partial(f, 2, t) * np.exp(-t / 0.45)
         + 0.1 * _partial(f, 3, t) * np.exp(-t / 0.2))
    return s * _attack(t, 0.004)


def pizz_bass(f, dur, sustain=False):
    """현 피치카토 베이스. sustain이면 활로 긋듯 길게 (가을·대기화면)"""
    n = int(SR * (dur + 0.5))
    t = _t(n)
    s = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * 2 * f * t)
         + 0.18 * np.sin(2 * np.pi * 3 * f * t) + 0.06 * np.sin(2 * np.pi * 4 * f * t))
    if sustain:
        e = _attack(t, 0.06) * np.clip((dur + 0.25 - t) / 0.25, 0, 1) * np.exp(-t / 2.5)
    else:
        e = _attack(t, 0.008) * np.exp(-t / max(0.28, dur * 0.7))
        e *= np.clip((dur + 0.4 - t) / 0.4, 0, 1)
    return s * e


def pad(freqs, dur, dark=False):
    """부드러운 현악 패드: 살짝 어긋난 두 줄, 느린 비브라토, 천천히 커지고 줄어든다"""
    rel = 0.7
    n = int(SR * (dur + rel))
    t = _t(n)
    out = np.zeros(n)
    nh = 4 if dark else 6
    for f in freqs:
        for det, ph0 in ((-0.003, 0.0), (0.003, 1.7)):
            vib = 1 + 0.0025 * np.sin(2 * np.pi * 4.8 * t + ph0)
            phase = 2 * np.pi * np.cumsum(f * (1 + det) * vib) / SR
            for k in range(1, nh + 1):
                if f * k > 6000:
                    break
                out += np.sin(k * phase + ph0 * k) / k ** 1.6
    e = _attack(t, 0.35) * np.clip((dur + rel - t) / rel, 0, 1) ** 2
    return out * e / (2 * len(freqs))


def soft_kick():
    n = int(SR * 0.3)
    t = _t(n)
    f = 70 * np.exp(-t / 0.05) + 52
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.11) * _attack(t, 0.003)


def shaker(rng, dur=0.07):
    n = int(SR * dur)
    t = _t(n)
    x = rng.uniform(-1, 1, n)
    b, a = butter(2, [3500 / (SR / 2), 9000 / (SR / 2)], btype="band")
    x = lfilter(b, a, x)
    return x * _attack(t, 0.006) * np.exp(-t / (dur / 3))


def woodblock(f=1400):
    n = int(SR * 0.08)
    t = _t(n)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.7 * t)
    return s * _attack(t, 0.0015) * np.exp(-t / 0.02)


def hand_drum(f=210):
    n = int(SR * 0.25)
    t = _t(n)
    ff = f * (1 + 0.15 * np.exp(-t / 0.02))
    s = np.sin(2 * np.pi * np.cumsum(ff) / SR)
    return s * _attack(t, 0.002) * np.exp(-t / 0.07)


def sleigh(rng):
    """썰매 방울: 작은 방울 여러 개, 날카롭지 않게"""
    n = int(SR * 0.22)
    t = _t(n)
    s = np.zeros(n)
    for _ in range(4):
        f = rng.uniform(3200, 5200)
        d = rng.uniform(0, 0.025)
        tt = np.clip(t - d, 0, None)
        s += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 1.5 * tt)) \
            * np.exp(-tt / 0.045) * _attack(tt, 0.002) * (t > d)
    return s * 0.25


def chirp(f0=2600):
    """봄: 작은 새 '삐릿'"""
    n = int(SR * 0.09)
    t = _t(n)
    f = f0 * (1 + 0.25 * np.sin(np.pi * t / 0.09))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR)
    return s * np.sin(np.pi * t / 0.09) ** 2


# ---------------- 작곡 (첫 버전 그대로) ----------------

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


# ---------------- 화성 ----------------

def pad_voicing(key_tonic, deg, prev, lo=53, hi=76, seventh=False):
    """화음 음들을 앞 화음과 가장 가깝게 이어지는 자리로 놓는다"""
    rel = chord_tones(deg)
    if seventh:
        rel = rel + [SCALE[(deg + 6) % 7] + 12 * ((deg + 6) // 7)]
    pcs = [(key_tonic + r) % 12 for r in rel]
    best, best_cost = None, 1e9
    for start in range(lo, lo + 12):
        for rot in range(len(pcs)):
            order = pcs[rot:] + pcs[:rot]
            v, cur = [], start - 1
            for pc in order:
                cur += 1
                while cur % 12 != pc:
                    cur += 1
                v.append(cur)
            if v[0] < lo or v[-1] > hi:
                continue
            if prev:
                cost = sum(min(abs(x - y) for y in prev) for x in v)
                cost += 0.3 * abs(np.mean(v) - 64)
            else:
                cost = abs(np.mean(v) - 64)
            if cost < best_cost:
                best, best_cost = v, cost
    return best


# ---------------- 소리 처리 (원형: 반복 이음매가 생기지 않게) ----------------

def circ_filter(x, b, a):
    """한 바퀴를 미리 돌려 필터 상태를 맞춘 뒤 적용 → 끝과 처음이 이어진다"""
    return lfilter(b, a, np.concatenate([x, x]))[len(x):]


def make_ir(rt60=1.5, seed=1):
    rng = np.random.default_rng(seed)
    n = int(SR * rt60 * 1.3)
    t = _t(n)
    noise = rng.standard_normal(n)
    b, a = butter(1, 3500 / (SR / 2))
    late = lfilter(b, a, noise) * np.exp(-6.9 * t / rt60)
    pre = int(0.018 * SR)
    ir = np.zeros(n + pre)
    ir[pre:] = late * _attack(t, 0.03)
    for ms, g in ((11, .5), (19, .4), (29, .35), (41, .25)):
        ir[int(ms / 1000 * SR)] += g * rng.choice([-1, 1]) * 3
    return ir / np.sqrt(np.sum(ir ** 2))


def circ_reverb(x, ir):
    """원형 합성곱: 끝의 잔향이 그대로 처음으로 이어진다"""
    n = len(x)
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)


def _kweight(x, sr=SR):
    """ITU-R BS.1770 K-가중 필터"""
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


def lufs(x, sr=SR, loop=True):
    """통합 음량 (게이트 포함, 모노)"""
    y = _kweight(np.concatenate([x, x]), sr)[len(x):] if loop else _kweight(x, sr)
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    ms = np.array([np.mean(y[i:i + blk] ** 2) for i in range(0, max(1, len(y) - blk), hop)])
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    ms = ms[lk > -70]
    rel = -0.691 + 10 * np.log10(np.mean(ms)) - 10
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    return -0.691 + 10 * np.log10(np.mean(ms[lk > rel]))


def soft_limit(x, ceil):
    """천장 근처만 부드럽게 눌러 준다 (샘플 단위, 시간에 따라 변하지 않음)"""
    thr = ceil * 0.75
    a = np.abs(x)
    over = a > thr
    y = x.copy()
    y[over] = np.sign(x[over]) * (thr + (ceil - thr) * np.tanh((a[over] - thr) / (ceil - thr)))
    return y


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def ffmpeg_lufs(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    summary = r[r.rindex("Summary:"):]
    return float(summary.split("I:")[1].split("LUFS")[0])


# ---------------- 곡 만들기 ----------------

def render(name, *, key, bpm, prog, rhythms, lead, seed, swing=0.0,
           drums="pop", arp="celesta", bass="bounce", dark_pad=False,
           extras=()):
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    eighth = beat / 2
    bars = 16
    bar_len = beat * 4
    total = int(round(SR * bar_len * bars))
    layers = {k: np.zeros(total + SR * 4) for k in ("lead", "arp", "pad", "bass", "perc")}

    def put(layer, sig, t, g):
        buf = layers[layer]
        i = int(round(t * SR))
        m = min(len(sig), len(buf) - i)
        buf[i:i + m] += sig[:m] * g

    def when(slot):  # 8분음표 위치 → 초 (스윙)
        t = slot * eighth
        if swing and slot % 2 == 1:
            t += eighth * swing
        return t

    full_prog = prog * 2
    melody = compose(seed, key, full_prog, rhythms)
    tonic = NOTE[key]

    def bass_note(deg):
        m = 36 + tonic + chord_tones(deg)[0]
        while m < 40:
            m += 12
        while m > 51:
            m -= 12
        return m

    voicing = None
    for b in range(bars):
        t0 = b * bar_len
        deg = full_prog[b]
        tones = chord_tones(deg)
        section_b = 8 <= b < 12

        # 화음 패드 (ii·V는 7음 더하기)
        voicing = pad_voicing(tonic, deg, voicing, seventh=deg in (1, 4))
        put("pad", pad([hz(m) for m in voicing], bar_len, dark=dark_pad), t0, 1.0)

        # 베이스
        root = bass_note(deg)
        fifth = root + 7 if root + 7 <= 55 else root - 5
        nroot = bass_note(full_prog[(b + 1) % bars])
        # 다음 근음으로 이어지는 음계 안의 경과음 (아래 또는 위에서 한 걸음)
        step = -1 if (nroot - 1 - tonic) % 12 in SCALE else -2
        if nroot <= root:
            step = 2 if (nroot + 2 - tonic) % 12 in SCALE else 1
        approach = nroot + step
        if bass == "bounce":
            pat = [(0, root, 2), (2, fifth, 2), (4, root, 2),
                   (6, fifth if b % 4 != 3 else approach, 2)]
        elif bass == "calypso":
            pat = [(0, root, 3), (3, fifth, 1), (4, root, 2), (6, approach, 2)]
        elif bass == "sustain":
            pat = [(0, root, 4), (4, fifth, 4)]
        else:  # "walk"
            pat = [(0, root, 2), (2, fifth, 2), (4, root + 12 if root + 12 <= 55 else root, 2),
                   (6, approach, 2)]
        for slot, m, d in pat:
            put("bass", pizz_bass(hz(m), eighth * d * 0.9, sustain=bass == "sustain"),
                t0 + when(slot), 1.0)

        # 분산 화음 (첫 버전의 음 그대로, 악기만 바꿈)
        apat = [0, 1, 2, 1, 0, 2, 1, 2]
        for k, p in enumerate(apat):
            if section_b and k % 2 == 1 and arp != "offbeat":
                continue  # 가운데 부분은 숨 쉬듯 성기게
            if arp == "offbeat" and k % 2 == 0:
                continue
            f = hz(72 + tonic + tones[p] + (12 if k % 4 == 3 else 0))
            if arp == "celesta":
                sig = celesta(f, eighth)
            elif arp in ("marimba", "offbeat"):
                sig = marimba(f, eighth, vel=0.6)
            elif arp == "guitar":
                sig = pluck(f / 2, eighth, rng, vel=0.5)
            else:
                sig = harp(f / 2 if k % 4 != 3 else f, eighth)
            put("arp", sig, t0 + when(k), 0.9 if k % 4 == 0 else 0.7)

        # 멜로디
        slot = 0
        for m, d in melody[b]:
            f = hz(m)
            vel = 1.0 if slot % 4 == 0 else 0.8
            sig = lead(f, eighth * d, rng, vel) if lead is pluck else lead(f, eighth * d, vel)
            put("lead", sig, t0 + when(slot) + rng.uniform(0, 0.004), 0.85 + 0.15 * vel)
            slot += d

        # 타악기 (작게, 강박만 살짝)
        for k in range(8):
            t = t0 + when(k)
            if drums == "pop":
                if k in (0, 4):
                    put("perc", soft_kick(), t, 1.0)
                if k % 2 == 1:
                    put("perc", shaker(rng), t, 0.35)
                if k in (2, 6):
                    put("perc", woodblock(1500 if k == 2 else 1300), t, 0.22)
            elif drums == "island":
                if k in (0, 4):
                    put("perc", soft_kick(), t, 0.9)
                put("perc", shaker(rng, 0.09), t, 0.45 if k % 2 else 0.28)
                if k in (3, 6):
                    put("perc", hand_drum(230 if k == 3 else 190), t, 0.35)
            elif drums == "soft":
                if k == 0 or (k == 4 and not section_b):
                    put("perc", soft_kick(), t, 0.75)
                if k in (2, 6):
                    put("perc", shaker(rng, 0.12), t, 0.3)
            elif drums == "jingle":
                if k in (0, 4):
                    put("perc", soft_kick(), t, 0.7)
                put("perc", sleigh(rng), t, 0.5 if k % 2 == 0 else 0.3)

        # 계절 장식
        if "birds" in extras and b % 4 == 3:
            put("perc", chirp(2700), t0 + when(6), 0.25)
            put("perc", chirp(3100), t0 + when(6) + 0.12, 0.2)
        if "chimes" in extras and b % 4 == 0:
            put("arp", chime(hz(72 + tonic)), t0, 0.9)
            put("arp", chime(hz(79 + tonic)), t0 + 2 * beat, 0.6)

    # 끝에서 넘친 울림을 처음에 겹쳐 끊김 없이 반복
    def fold(x):
        y = x[:total].copy()
        y[: len(x) - total] += x[total:]
        return y

    L = {k: fold(v) for k, v in layers.items()}

    def rms(x):
        return np.sqrt(np.mean(x ** 2)) + 1e-12

    # 층별 크기 (멜로디 기준 dB)
    level = {"lead": 0, "arp": -11, "pad": -14, "bass": -7, "perc": -19}
    if lead is pluck:
        level["arp"] = -13
    norm = {k: L[k] / rms(L[k]) * 10 ** (level[k] / 20) for k in L}
    dry = sum(norm.values())
    send = sum(norm[k] * s for k, s in
               (("lead", .35), ("arp", .45), ("pad", .5), ("perc", .2), ("bass", .08)))
    ir = make_ir(1.6 if name in ("winter", "home") else 1.3, seed)
    mix = dry + 0.32 * circ_reverb(send, ir)

    # 마무리 EQ: 아주 낮은 소리와 귀를 찌르는 높은 소리를 줄인다
    b, a = butter(2, 45 / (SR / 2), btype="high")
    mix = circ_filter(mix, b, a)
    b, a = butter(1, 7500 / (SR / 2))
    mix = 0.7 * mix + 0.3 * circ_filter(mix, b, a)

    # 음량 맞추기: 시간에 따라 변하지 않는 고정 배율 (이음매가 그대로 이어진다)
    mix *= 10 ** ((LUFS_TARGET - lufs(mix)) / 20)
    mix = soft_limit(mix, 10 ** (-2.0 / 20))
    mix *= 10 ** ((LUFS_TARGET - lufs(mix)) / 20)

    os.makedirs(OUT, exist_ok=True)
    fd, wav = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    write_wav(wav, mix)
    # ffmpeg(EBU R128) 측정값에 한 번 더 맞춘다 (재는 방법에 따른 작은 차이 보정)
    mix *= 10 ** ((LUFS_TARGET - ffmpeg_lufs(wav)) / 20)
    write_wav(wav, mix)
    mp3 = os.path.join(OUT, f"{name}.mp3")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
         "-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-q:a", MP3_QUALITY, mp3],
        check=True,
    )
    if os.environ.get("KEEP_WAV"):
        os.replace(wav, os.path.join(os.environ["KEEP_WAV"], f"{name}.wav"))
    else:
        os.remove(wav)
    print(f"{name:7s} {bpm}BPM {total / SR:5.1f}s {os.path.getsize(mp3) // 1024}KB "
          f"{lufs(mix):.1f} LUFS peak {20 * np.log10(np.max(np.abs(mix))):.1f} dBFS")


if __name__ == "__main__":
    # 리듬: 8분음표 단위 길이 목록 (한 마디 = 8)
    bouncy = [[1, 1, 2, 1, 1, 2], [2, 1, 1, 2, 2], [1, 1, 1, 1, 2, 2], [2, 2, 1, 1, 2]]
    island = [[1, 2, 1, 2, 2], [2, 1, 2, 1, 2], [1, 1, 2, 2, 2], [3, 1, 2, 2]]
    gentle = [[2, 2, 2, 2], [3, 1, 2, 2], [2, 1, 1, 4], [2, 2, 4]]
    jingly = [[2, 2, 2, 2], [1, 1, 2, 2, 2], [2, 2, 1, 1, 2], [2, 2, 4]]
    # 화음 진행 (음계 도수: 0=I 3=IV 4=V 5=vi 1=ii)
    # 봄: 밝은 C장조, 실로폰 + 첼레스타 반짝임 + 새소리
    render("spring", key="C", bpm=112, prog=[0, 4, 5, 3, 0, 4, 3, 4],
           rhythms=bouncy, lead=marimba, seed=11, drums="pop", arp="celesta",
           bass="bounce", extras=("birds",))
    # 여름: 경쾌한 F장조, 스틸드럼 + 엇박 실로폰 + 셰이커·손북
    render("summer", key="F", bpm=120, prog=[0, 3, 4, 0, 5, 3, 1, 4],
           rhythms=island, lead=steel, seed=23, drums="island", arp="offbeat",
           bass="calypso")
    # 가을: 따뜻한 G장조, 기타 + 낮고 어두운 현 + 길게 긋는 베이스, 흔들리는 박자
    render("autumn", key="G", bpm=96, prog=[0, 5, 3, 4, 0, 5, 1, 4],
           rhythms=gentle, lead=pluck, seed=37, swing=0.33, drums="soft",
           arp="guitar", bass="sustain", dark_pad=True)
    # 겨울: D장조, 첼레스타 + 썰매 방울 + 종소리
    render("winter", key="D", bpm=104, prog=[0, 3, 0, 4, 5, 3, 1, 4],
           rhythms=jingly, lead=celesta, seed=41, drums="jingle", arp="harp",
           bass="walk", extras=("chimes",))
    # 대기화면: 실로폰과 하프, 차분하게
    render("home", key="F", bpm=100, prog=[0, 5, 3, 4, 0, 5, 3, 4],
           rhythms=gentle, lead=marimba, seed=53, drums="soft", arp="harp",
           bass="sustain")
    # 상점: 첼레스타, 통통 튀게
    render("shop", key="G", bpm=112, prog=[0, 3, 4, 0, 5, 1, 4, 0],
           rhythms=bouncy, lead=celesta, seed=67, drums="pop", arp="marimba",
           bass="bounce")
