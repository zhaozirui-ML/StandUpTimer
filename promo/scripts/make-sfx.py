"""按 src/timeline.json 合成整片音效，输出 public/sfx/soundtrack.wav。

只用 Python 标准库：所有声音都是用正弦波、噪声和包络现场算出来的，没有版权问题。
改了 timeline.json 里的时间点后重新运行 `pnpm sfx`，音效会自动对齐画面。
"""

import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
T = json.loads((ROOT / "src" / "timeline.json").read_text(encoding="utf-8"))
SR = 48000
FPS = T["fps"]
TOTAL = int(T["duration"] / FPS * SR) + SR
random.seed(7)

left = [0.0] * TOTAL
right = [0.0] * TOTAL


def at(frame):
    """帧号 → 采样位置"""
    return int(frame / FPS * SR)


def place(samples, frame, gain=1.0, pan=0.0):
    """把一段单声道音效放到时间线上；pan -1 左 … 1 右（等功率声像）"""
    start = at(frame)
    angle = (pan + 1) * math.pi / 4
    gl, gr = math.cos(angle) * gain, math.sin(angle) * gain
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < TOTAL:
            left[j] += s * gl
            right[j] += s * gr


def lowpass(samples, cutoff):
    """一阶低通；cutoff 可以是常数或随采样变化的函数"""
    out, y = [], 0.0
    for i, x in enumerate(samples):
        c = cutoff(i) if callable(cutoff) else cutoff
        a = 1 - math.exp(-2 * math.pi * c / SR)
        y += a * (x - y)
        out.append(y)
    return out


def noise(n):
    return [random.uniform(-1, 1) for _ in range(n)]


# —— 基础音色 ——

def tick(freq=3200, dur=0.035):
    n = int(dur * SR)
    return [
        math.sin(2 * math.pi * freq * i / SR) * math.exp(-i / (0.004 * SR)) * 0.8
        + random.uniform(-1, 1) * math.exp(-i / (0.0012 * SR)) * 0.4
        for i in range(n)
    ]


def pop_snd(f0=900, f1=260, dur=0.14):
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f1 + (f0 - f1) * math.exp(-t * 6)
        phase += 2 * math.pi * f / SR
        env = min(1, i / (0.002 * SR)) * math.exp(-i / (0.045 * SR))
        out.append(math.sin(phase) * env)
    return out


def whoosh(dur=0.9, peak=0.55, lo=300, hi=5000):
    n = int(dur * SR)
    raw = noise(n)

    def cut(i):
        t = i / n
        k = math.sin(math.pi * min(1, t / peak) / 2) if t < peak else math.cos(math.pi * (t - peak) / (1 - peak) / 2)
        return lo + (hi - lo) * k

    filt = lowpass(lowpass(raw, cut), cut)
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


def swell(dur=3.6):
    """日出的升腾感：低通扫频的噪声 + 逐渐浮现的和声"""
    n = int(dur * SR)
    raw = noise(n)
    filt = lowpass(lowpass(raw, lambda i: 180 * (4000 / 180) ** (i / n)), lambda i: 180 * (4000 / 180) ** (i / n))
    chord = [220.0, 277.18, 329.63, 440.0, 554.37]
    out = []
    for i in range(n):
        t = i / n
        env = t ** 2 * (1 - max(0, (t - 0.92) / 0.08))
        tone = sum(math.sin(2 * math.pi * f * i / SR) for f in chord) / len(chord)
        out.append(filt[i] * env * 1.6 + tone * env * 0.22)
    return out


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
        f = random.uniform(2200, 6200)
        off = int(random.uniform(0, 0.7) * n)
        for i in range(min(int(0.3 * SR), n - off)):
            out[off + i] += math.sin(2 * math.pi * f * i / SR) * math.exp(-i / (0.06 * SR)) * 0.12
    return out


def pen(dur=0.9):
    """笔画在纸上划过：带通的细噪声"""
    n = int(dur * SR)
    band = lowpass(noise(n), 5200)
    band = [a - b for a, b in zip(band, lowpass(band, 1400))]
    return [s * math.sin(math.pi * i / n) ** 0.7 * 1.4 for i, s in enumerate(band)]


# —— 按场景排布 ——
I = T["intro"]
S0 = T["scenes"]["sunrise"]["from"]
SU = T["sunrise"]
F0 = T["scenes"]["features"]["from"]
BEAT = T["features"]["beat"]
O0 = T["scenes"]["outro"]["from"]
O = T["outro"]

# 开场：画椅子；计数器滴答越来越快，落定时一声闷响
place(pen(1.0), I["chairDraw"], 0.25, -0.2)
f, step = I["counterStart"], 12.0
flip = False
while f < I["counterEnd"]:
    place(tick(2600 if flip else 3300), int(f), 0.22, -0.15 if flip else 0.15)
    flip = not flip
    f += step
    step = max(3.0, step * 0.9)
place(thump(120, 55, 0.3, 0.3), I["counterEnd"], 0.5)

# 椅子飞进菜单栏
place(whoosh(1.4, 0.6, 250, 6000), I["flyStart"] - 6, 0.55, 0.3)
place(pop_snd(1100, 500, 0.1), I["personPop"] + 6, 0.35, 0.4)
place(pop_snd(700, 300, 0.16), I["calloutIn"], 0.4, 0.2)

# 专注快进：滴答 + 键盘声
f, step = I["lapseStart"], 8.0
while f < I["lapseEnd"]:
    place(tick(3000, 0.02), int(f), 0.12, 0.3)
    f += step
    step = max(2.0, step * 0.96)
for _ in range(90):
    fr = random.uniform(I["lapseStart"], I["lapseEnd"] - 10)
    place(tick(random.uniform(1500, 2400), 0.015), int(fr), 0.06, random.uniform(-0.6, 0.2))
place(bell([1318.5, 1975.5, 2637.0], 0.08), I["alarm"], 0.8, 0.2)

# 日出
place(whoosh(1.3, 0.5, 120, 1800), S0 + SU["wipe"], 0.5)
place(whoosh(0.8, 0.7, 400, 3000), S0 + SU["stand"], 0.3, 0.3)
place(pop_snd(760, 380, 0.18), S0 + SU["headPop"], 0.45, 0.3)
place(swell((SU["finale"] - SU["lapseStart"] + 30) / FPS), S0 + SU["lapseStart"], 0.5)
place(shimmer(1.4), S0 + SU["finale"], 0.9)

# 功能段
for b in range(4):
    place(whoosh(0.45, 0.4, 600, 4000), F0 + b * BEAT - 4, 0.22, -0.3)
for i in range(8):
    place(blip(880 * 2 ** ((i % 5) * 2 / 12)), F0 + 10 + i * 7, 0.25, -0.5 + i / 7)
for i in range(3):
    place(whoosh(0.5, 0.3, 200, 2500), F0 + BEAT + 34 + i * 4, 0.2, (i - 1) * 0.6)
place(thump(180, 70, 0.18, 0.8), F0 + BEAT * 2 + 40, 0.5)
place(bell([987.8], 0, 1.4), F0 + BEAT * 2 + 46, 0.35, 0.3)
for i in range(7):
    place(pop_snd(700 + i * 80, 320 + i * 40, 0.12), F0 + BEAT * 3 + 14 + i * 8, 0.3, -0.5 + i / 6)

# 收尾：画图标、贴纸拍上、最后一声轻响
place(pop_snd(500, 220, 0.2), O0 + O["base"], 0.35)
place(pen(1.2), O0 + O["draw"], 0.22, 0.1)
place(thump(210, 80, 0.2, 1.0), O0 + O["slap"], 0.75)
place(bell([1568.0, 2349.3], 0.1, 2.6), O0 + O["word"] + 12, 0.45)

# 归一化到 -1 dBFS，写 16-bit 立体声
peak = max(max(abs(v) for v in left), max(abs(v) for v in right)) or 1.0
g = 10 ** (-1 / 20) / peak
out = ROOT / "public" / "sfx" / "soundtrack.wav"
out.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(out), "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for a, b in zip(left, right):
        frames += struct.pack("<hh", int(max(-1, min(1, a * g)) * 32767), int(max(-1, min(1, b * g)) * 32767))
    w.writeframes(bytes(frames))
print(f"已生成 {out.relative_to(ROOT)}（{TOTAL / SR:.1f} 秒）")
