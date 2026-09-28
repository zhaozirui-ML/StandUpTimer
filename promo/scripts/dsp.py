"""音频合成的公共工具：只用 Python 标准库。"""

import math
import struct
import wave

SR = 48000


def midi(m):
    """MIDI 音高 → 频率（A4 = 69 = 440 Hz）"""
    return 440.0 * 2 ** ((m - 69) / 12)


def lowpass(samples, cutoff):
    """一阶低通；cutoff 可以是常数或 i → 频率 的函数"""
    out, y = [], 0.0
    if callable(cutoff):
        for i, x in enumerate(samples):
            a = 1 - math.exp(-2 * math.pi * cutoff(i) / SR)
            y += a * (x - y)
            out.append(y)
    else:
        a = 1 - math.exp(-2 * math.pi * cutoff / SR)
        for x in samples:
            y += a * (x - y)
            out.append(y)
    return out


def highpass(samples, cutoff):
    return [x - y for x, y in zip(samples, lowpass(samples, cutoff))]


class Bus:
    """立体声总线：把单声道片段按时间（秒）和声像放进来"""

    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.left = [0.0] * self.n
        self.right = [0.0] * self.n

    def place(self, samples, t, gain=1.0, pan=0.0):
        start = int(t * SR)
        angle = (max(-1.0, min(1.0, pan)) + 1) * math.pi / 4
        gl, gr = math.cos(angle) * gain, math.sin(angle) * gain
        left, right, n = self.left, self.right, self.n
        for i, s in enumerate(samples):
            j = start + i
            if j >= n:
                break
            if j >= 0:
                left[j] += s * gl
                right[j] += s * gr

    def peak(self):
        return max(max(map(abs, self.left)), max(map(abs, self.right))) or 1.0


def write_wav(path, left, right, gain=1.0):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        pack = struct.pack
        for a, b in zip(left, right):
            frames += pack("<hh", int(max(-1.0, min(1.0, a * gain)) * 32767), int(max(-1.0, min(1.0, b * gain)) * 32767))
        w.writeframes(bytes(frames))
