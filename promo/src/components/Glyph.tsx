import React from 'react';
import {interpolateColors} from 'remotion';
import {clamp01} from '../lib/anim';
import {color} from '../theme';

// 坐标系与 packaging/AppIcon.svg 一致（1024 画布，已包含原图的 translate(30 0)）
const CHAIR_BACK = 'M270 360 L340 590 L320 720';
const CHAIR_SEAT = 'M340 590 H500 L520 720';
// 身体从座面高度向上画：画的过程就是「站起来」
const SHAFT = 'M680 720 V440';
// 箭头从顶点向两侧展开，像张开肩膀
const ARROW_L = 'M680 440 L605 515';
const ARROW_R = 'M680 440 L755 515';
const HEAD = {cx: 680, cy: 318};
const LINE = 76;
const OUTLINE = 118;

export type GlyphProps = {
  id: string;
  // 画布中心 (512, 512) 在画面中的位置和画布边长
  x: number;
  y: number;
  size: number;
  // 各笔画的绘制进度 0..1
  chair?: number;
  shaft?: number;
  arrow?: number;
  head?: number;
  // 贴纸白边 0..1
  sticker?: number;
  // 0 = 全部冷色（坐着），1 = 图标原版渐变
  warmth?: number;
  // 椅子被推开时向后仰的角度
  tilt?: number;
  // 小人整体上移（画布单位）
  lift?: number;
  // 单色模式（菜单栏 template 图标），此时没有描边和渐变
  mono?: string;
  // 圆角底板缩放 0..1
  base?: number;
  opacity?: number;
  rotate?: number;
  scale?: number;
};

const Stroke: React.FC<{d: string; p: number; paint: string; width: number}> = ({d, p, paint, width}) => {
  if (p <= 0.001) return null;
  return (
    <path
      d={d}
      pathLength={1}
      stroke={paint}
      strokeWidth={width}
      strokeDasharray="1 1"
      strokeDashoffset={1 - clamp01(p)}
      fill="none"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  );
};

export const Glyph: React.FC<GlyphProps> = ({
  id,
  x,
  y,
  size,
  chair = 1,
  shaft = 1,
  arrow = 1,
  head = 1,
  sticker = 0,
  warmth = 1,
  tilt = 0,
  lift = 0,
  mono,
  base = 0,
  opacity = 1,
  rotate = 0,
  scale = 1,
}) => {
  const mid = interpolateColors(warmth, [0, 1], [color.cold, color.rose]);
  const end = interpolateColors(warmth, [0, 1], [color.cold, color.warm]);
  const paint = mono ?? `url(#${id}-g)`;
  const s = clamp01(sticker);
  const showOutline = !mono && s > 0.001;
  const outlineW = LINE + (OUTLINE - LINE) * s;
  const back = clamp01(chair * 2);
  const seat = clamp01(chair * 2 - 1);

  const layer = (layerPaint: string, width: number, headR: number) => (
    <>
      <g transform={`rotate(${tilt} 320 720)`}>
        <Stroke d={CHAIR_BACK} p={back} paint={layerPaint} width={width} />
        <Stroke d={CHAIR_SEAT} p={seat} paint={layerPaint} width={width} />
      </g>
      <g transform={`translate(0 ${-lift})`}>
        <Stroke d={SHAFT} p={shaft} paint={layerPaint} width={width} />
        <Stroke d={ARROW_L} p={arrow} paint={layerPaint} width={width} />
        <Stroke d={ARROW_R} p={arrow} paint={layerPaint} width={width} />
        {head > 0.001 ? <circle cx={HEAD.cx} cy={HEAD.cy} r={headR * head} fill={layerPaint} /> : null}
      </g>
    </>
  );

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 1024 1024"
      style={{
        position: 'absolute',
        left: x - size / 2,
        top: y - size / 2,
        overflow: 'visible',
        opacity,
        transform: `rotate(${rotate}deg) scale(${scale})`,
      }}
    >
      <defs>
        <linearGradient id={`${id}-g`} gradientUnits="userSpaceOnUse" x1="310" y1="740" x2="790" y2="290">
          <stop offset="0" stopColor={color.cold} />
          <stop offset="0.55" stopColor={mid} />
          <stop offset="1" stopColor={end} />
        </linearGradient>
        <linearGradient id={`${id}-bg`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={color.paperTop} />
          <stop offset="1" stopColor={color.paperBottom} />
        </linearGradient>
        <filter id={`${id}-sh`} x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="14" stdDeviation="16" floodColor={color.stickerShadow} floodOpacity={0.35 * s} />
        </filter>
        {/* 底板投影：底板和粉色背景同色，靠投影把轮廓托出来 */}
        <filter id={`${id}-base-sh`} x="-30%" y="-30%" width="160%" height="160%">
          <feDropShadow dx="0" dy="28" stdDeviation="34" floodColor={color.stickerShadow} floodOpacity="0.3" />
        </filter>
      </defs>
      {base > 0.001 ? (
        <g transform={`translate(512 512) scale(${base}) translate(-512 -512)`}>
          <rect x="100" y="100" width="824" height="824" rx="185" fill={`url(#${id}-bg)`} filter={`url(#${id}-base-sh)`} />
          {/* 顶部高光描边，模拟图标的立体边缘 */}
          <rect x="101.5" y="101.5" width="821" height="821" rx="183.5" fill="none" stroke="#FFFFFF" strokeOpacity="0.55" strokeWidth="3" />
        </g>
      ) : null}
      {showOutline ? <g filter={`url(#${id}-sh)`}>{layer(color.sticker, outlineW, outlineW / 2)}</g> : null}
      {layer(paint, LINE, LINE / 2)}
    </svg>
  );
};
