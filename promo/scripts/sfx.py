"""画面节点上的音效。时间点全部来自 src/timeline.json。

有音高的音效（提示音、功能段的「哔」）都落在 D 大调里，和配乐不打架。
"""

import math
import random

from dsp import SR, Bus, lowpass, midi

rnd = random.Random(7)


def noise(n):
    return [rnd.uniform(-1, 1) for _ in range(n)]


def tick(freq=3200, dur=0.035):
    n = int(dur * SR)
    return [
        math.sin(2 * math.pi * freq * i / SR) * math.exp(-i / (0.004 * SR)) * 0.8
        + rnd.uniform(-1, 1) * math.exp(-i / (0.0012 * SR)) * 0.4
        for i in range(n)
    ]


def pop_snd(f0=900, f1=260, dur=0.14):
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f1 + (f0 - f1) * math.exp(-t * 6)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * min(1, i / (0.002 * SR)) * math.exp(-i / (0.045 * SR)))
    return out


def whoosh(dur=0.9, peak=0.55, lo=300, hi=5000):
    n = int(dur * SR)

    def cut(i):
        t = i / n
        k = math.sin(math.pi * min(1, t / peak) / 2) if t < peak else math.cos(math.pi * (t - peak) / (1 - peak) / 2)
        return lo + (hi - lo) * k

    filt = lowpass(lowpass(noise(n), cut), cut)
    out = []
    for i, s in enumerate(filt):
        t = i / n
        env = (t / peak) ** 2 if t < peak else (1 - (t - peak) / (1 - peak)) ** 1.5
        out.append(s * env * 2.2)
    return out


def bell(freqs, spacing=0.09, dur=2.2):
    """玻璃质感的提示音：非整数倍泛音 + 各自衰减"""
    n = int(dur * SR)
    out = [0.0] * n
    partials = [(1.0, 1.0, 1.4), (2.0, 0.32, 0.8), (2.76, 0.22, 0.5), (5.4, 0.1, 0.22)]
    for k, f in enumerate(freqs):
        off = int(k * spacing * SR)
        for ratio, amp, decay in partials:
            w = 2 * math.pi * f * ratio / SR
            for i in range(n - off):
                out[off + i] += math.sin(w * i) * amp * math.exp(-i / (decay * SR)) * min(1, i / 60)
    return [s * 0.35 for s in out]


def thump(f0=150, f1=60, dur=0.22, grit=0.5):
    n = int(dur * SR)
    burst = lowpass(noise(n), 1800)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (f1 + (f0 - f1) * math.exp(-t * 8)) / SR
        out.append(math.sin(phase) * math.exp(-i / (0.07 * SR)) + burst[i] * grit * math.exp(-i / (0.012 * SR)) * 3)
    return out


def blip(f, dur=0.08):
    n = int(dur * SR)
    return [
        (math.sin(2 * math.pi * f * i / SR) + 0.3 * math.sin(4 * math.pi * f * i / SR))
        * min(1, i / (0.003 * SR))
        * math.exp(-i / (0.025 * SR))
        for i in range(n)
    ]


def shimmer(dur=1.2, count=26):
    n = int(dur * SR)
    out = [0.0] * n
    for _ in range(count):
        f = rnd.uniform(2200, 6200)
        off = int(rnd.uniform(0, 0.7) * n)
        for i in range(min(int(0.3 * SR), n - off)):
            out[off + i] += math.sin(2 * math.pi * f * i / SR) * math.exp(-i / (0.06 * SR)) * 0.12
    return out


def pen(dur=0.9):
    """笔画在纸上划过：带通的细噪声"""
    n = int(dur * SR)
    band = lowpass(noise(n), 5200)
    band = [a - b for a, b in zip(band, lowpass(band, 1400))]
    return [s * math.sin(math.pi * i / n) ** 0.7 * 1.4 for i, s in enumerate(band)]


def build_sfx(T):
    fps = T["fps"]
    bus = Bus(T["duration"] / fps + 1)

    def place(samples, frame, gain=1.0, pan=0.0):
        bus.place(samples, frame / fps, gain, pan)

    I = T["intro"]
    S0 = T["scenes"]["sunrise"]["from"]
    SU = T["sunrise"]
    F0 = T["scenes"]["features"]["from"]
    BEAT = T["features"]["beat"]
    O0 = T["scenes"]["outro"]["from"]
    O = T["outro"]

    # 开场：画椅子；计数器滴答越来越快，落定时一声闷响
    place(pen(1.0), I["chairDraw"], 0.25, -0.2)
    f, step, flip = I["counterStart"], 12.0, False
    while f < I["counterEnd"]:
        place(tick(2600 if flip else 3300), int(f), 0.2, -0.15 if flip else 0.15)
        flip = not flip
        f += step
        step = max(3.0, step * 0.9)
    place(thump(120, 55, 0.3, 0.3), I["counterEnd"], 0.45)

    # 椅子飞进菜单栏
    place(whoosh(1.4, 0.6, 250, 6000), I["flyStart"] - 6, 0.5, 0.3)
    place(pop_snd(1100, 500, 0.1), I["personPop"] + 6, 0.35, 0.4)
    place(pop_snd(700, 300, 0.16), I["calloutIn"], 0.4, 0.2)

    # 专注快进：时钟滴答 + 键盘声（配乐里已有 hi-hat，这里压低一些）
    f, step = I["lapseStart"], 8.0
    while f < I["lapseEnd"]:
        place(tick(3000, 0.02), int(f), 0.07, 0.3)
        f += step
        step = max(2.0, step * 0.96)
    for _ in range(90):
        fr = rnd.uniform(I["lapseStart"], I["lapseEnd"] - 10)
        place(tick(rnd.uniform(1500, 2400), 0.015), int(fr), 0.05, rnd.uniform(-0.6, 0.2))
    # 闹钟：配乐在这一拍全部停下，只留这一声
    place(bell([1318.5, 1975.5, 2637.0], 0.08), I["alarm"], 0.8, 0.2)

    # 日出
    place(whoosh(1.3, 0.5, 120, 1800), S0 + SU["wipe"], 0.45)
    place(whoosh(0.8, 0.7, 400, 3000), S0 + SU["stand"], 0.25, 0.3)
    place(pop_snd(760, 380, 0.18), S0 + SU["headPop"], 0.4, 0.3)
    place(shimmer(1.4), S0 + SU["finale"], 0.8)

    # 功能段：每个 beat 进场一声轻嗖；节奏块的「哔」按 D 大调五声音阶往上走
    for b in range(4):
        place(whoosh(0.45, 0.4, 600, 4000), F0 + b * BEAT - 4, 0.18, -0.3)
    penta = [81, 83, 86, 88, 90, 93, 95, 98]
    for i in range(8):
        place(blip(midi(penta[i])), F0 + 10 + i * 7, 0.2, -0.5 + i / 7)
    for i in range(3):
        place(whoosh(0.5, 0.3, 200, 2500), F0 + BEAT + 34 + i * 4, 0.18, (i - 1) * 0.6)
    place(thump(180, 70, 0.18, 0.8), F0 + BEAT * 2 + 40, 0.45)
    place(bell([midi(83)], 0, 1.4), F0 + BEAT * 2 + 46, 0.3, 0.3)
    for i in range(7):
        place(pop_snd(700 + i * 80, 320 + i * 40, 0.12), F0 + BEAT * 3 + 14 + i * 8, 0.28, -0.5 + i / 6)

    # 收尾：底板冒出、画图标、贴纸拍上
    place(pop_snd(500, 220, 0.2), O0 + O["base"], 0.3)
    place(pen(1.2), O0 + O["draw"], 0.2, 0.1)
    place(thump(210, 80, 0.2, 1.0), O0 + O["slap"], 0.7)
    return bus
