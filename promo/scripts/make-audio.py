"""合成整片音频：配乐 + 音效，按 src/timeline.json 对齐画面。

输出到 public/sfx/：
  soundtrack.wav  最终混音（视频里用这一条）
  music.wav       纯配乐分轨
  sfx.wav         纯音效分轨
改了 timeline.json 或乐谱后重新运行 `pnpm audio`。
"""

import json
import math
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dsp import SR, write_wav  # noqa: E402
from music import build_music  # noqa: E402
from sfx import build_sfx  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "public" / "sfx"
T = json.loads((ROOT / "src" / "timeline.json").read_text(encoding="utf-8"))

started = time.time()
print("合成配乐…")
music = build_music(T)
print(f"  完成（{time.time() - started:.0f} 秒）")
print("合成音效…")
sfx = build_sfx(T)

n = int(T["duration"] / T["fps"] * SR)
music_gain = 0.5 / music.peak()
sfx_gain = 0.8 / sfx.peak()

# 音效响的时候把配乐压低一点（ducking），让提示音、贴纸声更清楚
env, level = [0.0] * n, 0.0
release = math.exp(-1 / (0.18 * SR))
for i in range(n):
    a = max(abs(sfx.left[i]), abs(sfx.right[i])) * sfx_gain
    level = a if a > level else level * release
    env[i] = level

# 结尾 0.6 秒淡出，避免混响尾巴被硬切
fade = int(0.6 * SR)
left, right = [0.0] * n, [0.0] * n
for i in range(n):
    duck = 1 - 0.4 * min(1.0, env[i] / 0.5)
    tail = min(1.0, (n - i) / fade)
    left[i] = (music.left[i] * music_gain * duck + sfx.left[i] * sfx_gain) * tail
    right[i] = (music.right[i] * music_gain * duck + sfx.right[i] * sfx_gain) * tail

# 响度：先把整体 RMS 提到约 -15 dB，再用限幅器压住峰值（-1 dBFS），网络视频里不会显得太小声
rms = math.sqrt(sum(a * a + b * b for a, b in zip(left, right)) / (2 * n))
pre = 10 ** (-15 / 20) / rms
ceiling = 10 ** (-1 / 20)
limit_release = math.exp(-1 / (0.08 * SR))
level = 0.0
for i in range(n):
    a, b = left[i] * pre, right[i] * pre
    p = max(abs(a), abs(b))
    level = p if p > level else level * limit_release
    g = ceiling / level if level > ceiling else 1.0
    left[i], right[i] = a * g, b * g

write_wav(OUT / "soundtrack.wav", left, right)
# 分轨用同样的增益，方便在剪辑软件里和成片对齐
write_wav(OUT / "music.wav", music.left[:n], music.right[:n], min(1.0, music_gain * pre))
write_wav(OUT / "sfx.wav", sfx.left[:n], sfx.right[:n], min(1.0, sfx_gain * pre))
print(f"已生成 soundtrack.wav / music.wav / sfx.wav（{n / SR:.1f} 秒，用时 {time.time() - started:.0f} 秒）")
