"""全片配乐：暖色 Lo-fi，120 BPM，15 小节 = 30 秒。

叙事和画面一致：从冷到暖、从坐到站。
  第 1–2 小节   坐着      D 小调，稀疏的电钢琴动机，冷色 pad
  第 3–5 小节   菜单栏    拨弦琶音进来，鼓逐渐加密，跟着时间快进一起加速
  第 6 小节     闹钟      全部静音，只留闹钟声
  第 7–9 小节   日出      pad 慢慢升起，人站起来的那一拍落下 D 大调和弦
  第 10–13 小节 功能      完整的 Lo-fi 律动，一个功能一小节
  第 14–15 小节 收尾      开场动机改成大调再弹一次，贴纸拍上时落在主和弦

乐谱写成「小节, 拍」的形式（拍从 0 开始），改音符只改这里。
"""

import math
import random

from dsp import SR, Bus, highpass, lowpass, midi

rnd = random.Random(11)


# —— 乐器 ——

def keys(freq, dur, vel=0.5):
    """电钢琴：基音 + 快速衰减的泛音，带一点磁带式的音高摇摆"""
    tail = 1.4
    n = int((dur + tail) * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        wobble = 1 + 0.0022 * math.sin(2 * math.pi * 0.6 * t)
        phase += 2 * math.pi * freq * wobble / SR
        env = min(1.0, t / 0.004) * math.exp(-t / 1.1)
        if t > dur:
            env *= math.exp(-(t - dur) / 0.25)
        s = (
            math.sin(phase)
            + 0.32 * math.sin(2 * phase) * math.exp(-t / 0.35)
            + 0.1 * math.sin(3 * phase) * math.exp(-t / 0.18)
            + 0.06 * math.sin(7 * phase) * math.exp(-t / 0.04)
        )
        out.append(s * env * vel * 0.5)
    return lowpass(out, 4200)


def pluck(freq, dur, vel=0.5, bright=0.5):
    """Karplus-Strong 拨弦：一小段噪声在延迟线里反复平均，自然衰减成琴弦的声音。

    延迟线只能是整数个采样，高音会跑调；用一个全通滤波补上小数部分的延迟来精确调音。
    环路总延迟 = period - 0.5（相邻两点求平均）+ frac（全通），frac 取 0.1..1.1 保持稳定。
    """
    total = SR / freq
    period = int(total + 0.4)
    frac = total + 0.5 - period
    coef = (1 - frac) / (1 + frac)
    ring = lowpass([rnd.uniform(-1, 1) for _ in range(period)], 1500 + 6000 * bright)
    peak = max(map(abs, ring)) or 1.0
    ring = [x / peak for x in ring]
    n = int(dur * SR)
    fade = int(0.02 * SR)
    out, idx = [], 0
    ap_in = ap_out = 0.0
    for i in range(n):
        y = ring[idx]
        avg = 0.5 * (y + ring[(idx + 1) % period]) * 0.996
        ap_out = coef * avg + ap_in - coef * ap_out
        ap_in = avg
        ring[idx] = ap_out
        idx = (idx + 1) % period
        g = 1.0 if i < n - fade else (n - i) / fade
        out.append(y * g * vel)
    return out


def pad_note(freq, dur, vel, cut0, cut1, attack=0.4, release=0.8):
    """一个 pad 音：两个略微走音的锯齿波 + 随时间打开或收拢的低通"""
    n = int((dur + release) * SR)
    detune = 2 ** (7 / 1200)
    f1, f2 = freq * detune, freq / detune
    p1, p2 = rnd.random(), rnd.random()
    raw = []
    for i in range(n):
        p1 = (p1 + f1 / SR) % 1.0
        p2 = (p2 + f2 / SR) % 1.0
        raw.append((p1 - 0.5) + (p2 - 0.5))
    span = max(1, int(dur * SR))

    def cut(i):
        return cut0 * (cut1 / cut0) ** min(1.0, i / span)

    filt = lowpass(lowpass(raw, cut), cut)
    out = []
    for i, s in enumerate(filt):
        t = i / SR
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if t > dur:
            env *= max(0.0, 1 - (t - dur) / release)
        out.append(s * env * vel)
    return out


def bass(freq, dur, vel=0.6):
    """贝斯：正弦 + 二次谐波，轻微饱和"""
    n = int((dur + 0.08) * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        phase += 2 * math.pi * freq / SR
        env = min(1.0, t / 0.006) * (0.55 + 0.45 * math.exp(-t / 0.25))
        if t > dur:
            env *= max(0.0, 1 - (t - dur) / 0.08)
        s = math.sin(phase) + 0.28 * math.sin(2 * phase)
        out.append(math.tanh(1.6 * s) * env * vel)
    return out


def sub_boom(freq=36.7, dur=1.6, vel=0.9):
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        phase += 2 * math.pi * freq * (1 + 0.6 * math.exp(-t / 0.05)) / SR
        out.append(math.sin(phase) * math.exp(-t / 0.55) * vel)
    return out


def kick(vel=0.8):
    n = int(0.32 * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        phase += 2 * math.pi * (44 + 76 * math.exp(-t / 0.03)) / SR
        out.append(math.sin(phase) * math.exp(-t / 0.13) * vel)
    return lowpass(out, 2400)


def snap(vel=0.5):
    """Lo-fi 军鼓 / 响指：几次极短的噪声爆发 + 一点鼓身"""
    n = int(0.22 * SR)
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    band = highpass(lowpass(raw, 3800), 900)
    out = []
    for i, s in enumerate(band):
        t = i / SR
        env = sum(math.exp(-(t - d) / 0.008) for d in (0.0, 0.009, 0.018) if t >= d) * 0.5 + math.exp(-t / 0.09) * 0.6
        body = math.sin(2 * math.pi * 185 * t) * math.exp(-t / 0.04) * 0.4
        out.append((s * env * 1.6 + body) * vel)
    return lowpass(out, 6000)


def hat(vel=0.3, open_=False):
    n = int((0.18 if open_ else 0.05) * SR)
    raw = highpass([rnd.uniform(-1, 1) for _ in range(n)], 7000)
    decay = 0.06 if open_ else 0.012
    return [s * math.exp(-(i / SR) / decay) * vel for i, s in enumerate(raw)]


def shaker(vel=0.2):
    n = int(0.09 * SR)
    raw = highpass([rnd.uniform(-1, 1) for _ in range(n)], 5000)
    return [s * min(1.0, (i / SR) / 0.012) * math.exp(-(i / SR) / 0.03) * vel for i, s in enumerate(raw)]


def reverse_swell(dur=1.5, vel=0.4, lo=400, hi=9000):
    """反向镲片感的噪声渐强，落在下一小节的第一拍"""
    n = int(dur * SR)
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    filt = lowpass(raw, lambda i: lo * (hi / lo) ** (i / n))
    return [s * (i / n) ** 2.5 * vel for i, s in enumerate(filt)]


def reverb(mono, seconds):
    """简化版 Freeverb：4 个并联梳状滤波 + 2 个串联全通，左右声道延迟略有不同"""
    n = int(seconds * SR)
    x = mono + [0.0] * max(0, n - len(mono))

    def channel(offset):
        acc = [0.0] * n
        for length in (1557, 1617, 1491, 1422):
            size = int(length * 1.09) + offset
            buf = [0.0] * size
            idx, store = 0, 0.0
            for i in range(n):
                y = buf[idx]
                store = y * 0.7 + store * 0.3
                buf[idx] = x[i] + store * 0.84
                idx = (idx + 1) % size
                acc[i] += y
        for length in (556, 441):
            size = length + offset
            buf = [0.0] * size
            idx = 0
            for i in range(n):
                b = buf[idx]
                y = -acc[i] + b
                buf[idx] = acc[i] + b * 0.5
                idx = (idx + 1) % size
                acc[i] = y
        return [v * 0.18 for v in acc]

    return channel(0), channel(23)


# —— 编曲 ——

def build_music(T):
    beat = 60 / T["bpm"]
    seconds = T["duration"] / T["fps"] + 2.5

    def at(bar, b=0.0):
        return ((bar - 1) * 4 + b) * beat

    def hum(t):
        return t + rnd.uniform(-0.004, 0.004)

    dry = Bus(seconds)
    pads = Bus(seconds)
    send = [0.0] * int(seconds * SR)
    kicks = []

    def to_send(samples, t, amount):
        start = int(t * SR)
        for i, s in enumerate(samples):
            j = start + i
            if j >= len(send):
                break
            send[j] += s * amount

    def play(samples, t, gain, pan=0.0, rev=0.0, bus=None):
        (bus or dry).place(samples, t, gain, pan)
        if rev:
            to_send(samples, t, gain * rev)

    # 和弦（MIDI）：D 小调部分偏冷，日出之后换到 D 大调
    Dm9 = [50, 53, 57, 60, 64]
    Bbmaj7 = [46, 53, 57, 62]
    Gm7 = [43, 53, 58, 62]
    A7sus = [45, 55, 62, 64]
    A7 = [45, 55, 61, 64]
    Dsus = [50, 57, 64]
    Dmaj9 = [38, 50, 57, 61, 64, 66]
    Gmaj9 = [43, 54, 59, 62, 69]
    Bm7 = [47, 54, 57, 62, 66]
    Asus = [45, 52, 59, 62, 64]
    Amaj = [45, 52, 57, 61, 64]

    def pad(chord, t, dur, vel, c0, c1, attack=0.4, release=0.8):
        for k, m in enumerate(chord):
            pan = -0.6 + 1.2 * k / max(1, len(chord) - 1)
            note = pad_note(midi(m), dur, vel, c0, c1, attack, release)
            play(note, t, 1.0, pan, rev=0.35, bus=pads)

    # ---------- 第 1–2 小节：坐着 ----------
    pad(Dm9, at(1), 2.0, 0.05, 320, 700, attack=0.8)
    pad(Bbmaj7, at(2), 2.0, 0.05, 500, 850)
    for bar, b, m, d, v in [
        (1, 1, 69, 1.2, 0.5), (1, 2, 74, 1.2, 0.45), (1, 3, 77, 1.4, 0.5),
        (2, 0, 76, 1.6, 0.5), (2, 2, 74, 1.2, 0.4), (2, 3, 69, 1.0, 0.35),
    ]:
        play(keys(midi(m), d, v), hum(at(bar, b)), 0.9, 0.15, rev=0.5)

    # ---------- 第 3–5 小节：菜单栏 + 专注快进 ----------
    pad(Dm9, at(3), 2.0, 0.04, 600, 900)
    pad(Bbmaj7, at(4), 2.0, 0.04, 700, 1100)
    pad(Gm7, at(5), 1.0, 0.045, 900, 1500)
    pad(A7sus, at(5, 2), 0.5, 0.05, 1500, 2100, attack=0.05, release=0.05)
    pad(A7, at(5, 3), 0.5, 0.055, 2100, 2800, attack=0.05, release=0.03)
    arps = [
        (3, [62, 65, 69, 72], 2, 0.22, 0.3),
        (4, [58, 62, 65, 69], 2, 0.26, 0.45),
    ]
    for bar, tones, per_beat, vel, bright in arps:
        order = tones + tones[-2:0:-1]
        for step in range(4 * per_beat):
            t = at(bar, step / per_beat)
            play(pluck(midi(order[step % len(order)]), 0.45, vel, bright), hum(t), 0.8, -0.35 + 0.1 * (step % 2), rev=0.3)
    # 第 5 小节变成 16 分音符：跟着画面里的时间快进一起加速
    for step in range(16):
        b = step / 4
        tones = [55, 58, 62, 65] if b < 2 else ([57, 62, 64, 67] if b < 3 else [57, 61, 64, 69])
        play(pluck(midi(tones[step % 4] + 12 * (step // 8)), 0.25, 0.26 + step * 0.008, 0.6), hum(at(5, b)), 0.8, -0.3, rev=0.25)
    for bar, notes in [
        (3, [(0, 38, 1.8), (2.5, 38, 0.4), (3, 45, 0.8)]),
        (4, [(0, 46, 1.8), (2.5, 46, 0.4), (3, 41, 0.8)]),
        (5, [(0, 43, 1.5), (2, 45, 0.9), (3, 45, 0.4), (3.5, 45, 0.4)]),
    ]:
        for b, m, d in notes:
            play(bass(midi(m), d * beat, 0.55), at(bar, b), 1.0)
    for step in range(2, 8):
        play(shaker(0.16), hum(at(3, step / 2)), 1.0, 0.4)
    for b in (0, 2, 2.5):
        kicks.append(at(4, b))
    for b in (0, 1.5, 2, 3):
        kicks.append(at(5, b))
    for b in (1, 3):
        play(snap(0.34), hum(at(4, b)), 1.0, 0.05, rev=0.2)
        play(snap(0.36), hum(at(5, b)), 1.0, 0.05, rev=0.2)
    for step in range(8):
        swing = 0.03 if step % 2 else 0.0
        play(hat(0.2 + 0.05 * (step % 2)), hum(at(4, step / 2) + swing), 1.0, 0.3)
    for step in range(16):
        play(hat(0.14 + step * 0.012), hum(at(5, step / 4)), 1.0, 0.3)
    for k, b in enumerate([3, 3.25, 3.5, 3.625, 3.75, 3.875]):
        play(snap(0.18 + k * 0.05), at(5, b), 1.0, 0.0)
    play(reverse_swell(1.6, 0.35), at(6) - 1.6, 1.0)

    # ---------- 第 6 小节：闹钟，全部静音 ----------
    # 日出从画面第 620 帧开始，低音 pad 从这里慢慢浮上来
    sunrise_t = T["scenes"]["sunrise"]["from"] / T["fps"]
    pad(Dsus, sunrise_t + 0.1, at(7, 2) - sunrise_t - 0.1, 0.045, 260, 1400, attack=1.8, release=0.1)

    # ---------- 第 7–9 小节：日出 ----------
    stand = at(7, 2)  # 人站起来（头冒出来）的那一拍
    play(reverse_swell(1.0, 0.3, 600, 7000), stand - 1.0, 1.0)
    pad(Dmaj9, stand, 1.0, 0.06, 2600, 1500, attack=0.01, release=0.3)
    play(sub_boom(36.7, 1.8, 0.8), stand, 1.0)
    kicks.append(stand)
    for k, m in enumerate([62, 66, 69, 73, 76, 81]):
        play(keys(midi(m), 1.6, 0.34), stand + k * 0.018, 0.9, -0.4 + k * 0.16, rev=0.55)
    pad(Gmaj9, at(8), 2.0, 0.055, 1300, 1900)
    pad(Bm7, at(9), 1.0, 0.055, 1500, 2100)
    pad(Asus, at(9, 2), 0.5, 0.055, 1900, 2300)
    pad(Amaj, at(9, 3), 1.0, 0.055, 2300, 2600, release=0.3)
    for bar, b, m, d in [
        (8, 0, 78, 1.0), (8, 1, 81, 0.5), (8, 1.5, 78, 0.5), (8, 2, 76, 1.5),
        (9, 0, 74, 1.0), (9, 1, 76, 0.5), (9, 1.5, 78, 0.5), (9, 2, 81, 1.2),
    ]:
        play(keys(midi(m), d * beat + 0.2, 0.42), hum(at(bar, b)), 0.9, 0.2, rev=0.55)
    for bar, tones in [(8, [59, 62, 66, 69]), (9, [62, 66, 69, 74])]:
        for step in range(8):
            v = 0.1 + 0.02 * step + (0.05 if bar == 9 else 0)
            play(pluck(midi(tones[step % 4] + 12), 0.4, v, 0.4), hum(at(bar, step / 2)), 0.8, 0.4 - 0.1 * (step % 2), rev=0.35)
    for b, m, d in [(0, 43, 2.0)]:
        play(bass(midi(m), d * beat, 0.45), at(8, b), 1.0)
    for b, m, d in [(0, 47, 1.0), (2, 45, 1.0)]:
        play(bass(midi(m), d * beat, 0.5), at(9, b), 1.0)
    for step in range(4, 8):
        play(shaker(0.12), hum(at(8, step / 2)), 1.0, 0.4)
    for b in (0, 2):
        kicks.append(at(9, b))
    for step in range(8):
        play(hat(0.16 + 0.04 * (step % 2)), hum(at(9, step / 2) + (0.03 if step % 2 else 0)), 1.0, 0.3)
    for k, b in enumerate([3, 3.25, 3.5, 3.75]):
        play(snap(0.2 + k * 0.06), at(9, b), 1.0)
    play(reverse_swell(1.4, 0.3), at(10) - 1.4, 1.0)

    # ---------- 第 10–13 小节：功能段律动 ----------
    groove = [
        (10, Dmaj9, [62, 66, 69], [(0, 38, 0.9), (1.5, 38, 0.4), (2, 45, 0.4), (2.75, 38, 0.3), (3.5, 50, 0.3)]),
        (11, Bm7, [62, 66, 69], [(0, 47, 0.9), (1.5, 47, 0.4), (2, 42, 0.4), (2.75, 47, 0.3), (3.5, 54, 0.3)]),
        (12, Gmaj9, [62, 66, 71], [(0, 43, 0.9), (1.5, 43, 0.4), (2, 50, 0.4), (2.75, 43, 0.3), (3.5, 47, 0.3)]),
        (13, Asus, [64, 69, 71], [(0, 45, 0.9), (1.5, 45, 0.4), (2, 52, 0.4), (2.75, 45, 0.3), (3.5, 49, 0.4)]),
    ]
    for bar, chord, stab, line in groove:
        pad(chord if bar != 13 else Asus, at(bar), 2.0 if bar != 13 else 1.0, 0.045, 1500, 1900)
        if bar == 13:
            pad(Amaj, at(13, 2), 1.0, 0.045, 1900, 2400, release=0.3)
        # 反拍的拨弦和弦
        for b in (0.5, 1.5, 3.5):
            for k, m in enumerate(stab):
                play(pluck(midi(m), 0.3, 0.2, 0.55), hum(at(bar, b) + 0.03 + k * 0.006), 0.8, -0.2 + k * 0.2, rev=0.3)
        for b, m, d in line:
            play(bass(midi(m), d * beat, 0.6), at(bar, b), 1.0)
        for b in (0, 0.75, 2, 2.5):
            kicks.append(at(bar, b))
        for b in (1, 3):
            play(snap(0.4), hum(at(bar, b)), 1.0, 0.05, rev=0.2)
        for step in range(8):
            swing = 0.03 if step % 2 else 0.0
            is_open = step == 7 and bar in (11, 13)
            play(hat(0.24 if step % 2 == 0 else 0.16, is_open), hum(at(bar, step / 2) + swing), 1.0, 0.3)
        for step in range(16):
            play(shaker(0.06 + (0.03 if step % 4 == 2 else 0)), hum(at(bar, step / 4) + (0.015 if step % 2 else 0)), 1.0, -0.4)
        play(keys(midi(chord[-1] + 12 if chord[-1] < 70 else chord[-1]), 1.2, 0.2), hum(at(bar)), 0.9, 0.3, rev=0.5)
    for b in (3.5, 3.75):
        play(snap(0.3), at(13, b), 1.0)
    play(reverse_swell(1.2, 0.25), at(14) - 1.2, 1.0)

    # ---------- 第 14–15 小节：收尾 ----------
    pad(Gmaj9, at(14), 2.0, 0.05, 1700, 1100)
    # 开场动机改成大调：F 变成 F#
    for b, m in [(0, 69), (1, 74), (2, 78), (3, 76)]:
        play(keys(midi(m), 0.9, 0.46), hum(at(14, b)), 0.9, 0.1, rev=0.55)
    for step in range(4):
        play(hat(0.12), hum(at(14, step)), 1.0, 0.3)
    play(bass(midi(43), 2 * beat, 0.45), at(14), 1.0)
    slap = at(15)
    pad(Dmaj9, slap, 1.6, 0.06, 2600, 600, attack=0.01, release=0.6)
    play(sub_boom(36.7, 2.0, 0.85), slap, 1.0)
    kicks.append(slap)
    for k, m in enumerate([62, 66, 69, 73, 76]):
        play(keys(midi(m), 1.8, 0.36), slap + k * 0.022, 0.9, -0.4 + k * 0.2, rev=0.6)
    play(keys(midi(81), 1.4, 0.3), hum(at(15, 1.5)), 0.9, 0.3, rev=0.65)
    play(keys(midi(86), 1.6, 0.26), hum(at(15, 2.5)), 0.9, 0.35, rev=0.7)

    # 底鼓：放进总线，同时让 pad 跟着「呼吸」（sidechain）
    for t in kicks:
        play(kick(0.75), t, 1.0)
    duck = [1.0] * pads.n
    for t in kicks:
        start = int(t * SR)
        for i in range(int(0.3 * SR)):
            j = start + i
            if 0 <= j < pads.n:
                duck[j] = min(duck[j], 1 - 0.45 * math.exp(-i / (0.09 * SR)))
    for i in range(pads.n):
        dry.left[i] += pads.left[i] * duck[i]
        dry.right[i] += pads.right[i] * duck[i]

    # 黑胶底噪：稀疏的噼啪声 + 很轻的嘶声，Lo-fi 的质感来源
    crackle = [0.0] * dry.n
    for i in range(dry.n):
        if rnd.random() < 26 / SR:
            crackle[i] = rnd.choice((-1, 1)) * rnd.uniform(0.3, 1.0)
    crackle = highpass(lowpass(crackle, 5000), 800)
    hiss = lowpass([rnd.uniform(-1, 1) for _ in range(dry.n)], 5000)
    for i in range(dry.n):
        v = crackle[i] * 0.05 + hiss[i] * 0.004
        dry.left[i] += v
        dry.right[i] += v * 0.9

    # 混响
    wl, wr = reverb(send, seconds)
    for i in range(dry.n):
        dry.left[i] += wl[i]
        dry.right[i] += wr[i]

    # 母带：轻微压暗高频 + 软削波
    dry.left = [math.tanh(1.1 * v) for v in lowpass(dry.left, 11000)]
    dry.right = [math.tanh(1.1 * v) for v in lowpass(dry.right, 11000)]
    return dry
