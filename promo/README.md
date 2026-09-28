# StandUpTimer 产品短片

用 [Remotion](https://www.remotion.dev)（用 React 写视频的框架）制作的 30 秒产品动画，输出 16:9、1:1、9:16 三种比例。

## 命令

```sh
pnpm install
pnpm audio     # 按时间轴合成配乐和音效 → public/sfx/（约 30 秒）
pnpm studio    # 浏览器里实时预览，可拖时间轴逐帧看
pnpm render    # 合成音频并导出三种比例到 out/
pnpm typecheck
```

字体用的是本机安装的 SF Pro Rounded 和 PingFang SC，换电脑渲染前要确认已安装。

## 结构

- `src/timeline.json`：全片的时间点，画面和音频共用这一份；关键动作都对齐在 120 BPM 的小节线上
- `src/theme.ts`：颜色和字体 token，全部取自 App 图标
- `src/components/Glyph.tsx`：图标字形，每一笔都能单独动画（椅子、身体、箭头、头、贴纸白边）
- `src/scenes/`：四个场景，按出场顺序为 Intro → Sunrise → Features → Outro
- `scripts/`：只用 Python 标准库合成的音频，没有版权问题
  - `music.py`：配乐，暖色 Lo-fi，120 BPM，15 小节，乐谱按「小节, 拍」写
  - `sfx.py`：画面节点上的音效
  - `make-audio.py`：混音，输出 `soundtrack.wav`（成片用）和 `music.wav`、`sfx.wav` 两条分轨

## 分镜

| 时间 | 场景 | 内容 |
|---|---|---|
| 0–4s | 坐着 | 椅子一笔画出，计数器跳到「3 小时 12 分钟」 |
| 4–10s | 菜单栏 | 椅子飞进菜单栏变成图标，25 分钟专注快进 |
| 10–18s | 日出 | 遮罩从屏幕里升起，人从椅子上站起来，太阳随休息进度升起 |
| 18–25s | 功能 | 番茄节奏、全屏覆盖、睡眠感知、今日统计 |
| 25–30s | 收尾 | 图标画出并像贴纸一样贴上，字标与 slogan |

「日出」段是遮罩视觉方向 A 的动态概念稿，跳过改为长按 Esc 也是提案，App 里还没实现。
