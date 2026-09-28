import React from 'react';
import {AbsoluteFill, Sequence, useCurrentFrame} from 'remotion';
import {Glyph} from '../components/Glyph';
import {SunriseBackdrop} from '../components/SunriseBackdrop';
import {LineReveal} from '../components/Type';
import {easeIn, easeInOut, easeOut, pop, tween} from '../lib/anim';
import {Layout, pick, Rect, useLayout} from '../lib/layout';
import {color, font} from '../theme';
import T from '../timeline.json';

const BEAT = T.features.beat;

type VisualProps = {frame: number; box: Rect; L: Layout};

// —— 01 番茄节奏：冷色块 = 专注（坐着），暖色块 = 站立 ——
const Rhythm: React.FC<VisualProps> = ({frame, box, L}) => {
  const all = [25, 5, 25, 5, 25, 5, 25, 20];
  const rows = L.format === 'portrait' ? [all.slice(0, 4), all.slice(4)] : [all];
  const gap = 14;
  const longest = Math.max(...rows.map((r) => r.reduce((a, b) => a + b, 0)));
  const maxCount = Math.max(...rows.map((r) => r.length));
  const unit = (box.w - gap * (maxCount - 1)) / longest;
  const blockH = pick(L, {landscape: 150, square: 140, portrait: 170});
  const rowGap = blockH + 90;
  const top = box.y + (box.h - (rows.length * rowGap - 90)) / 2;
  let index = 0;
  return (
    <>
      {rows.map((row, r) => {
        let x = box.x;
        return row.map((min) => {
          const i = index++;
          const start = 10 + i * 7;
          const p = pop(frame, start, L.fps, {damping: 16, stiffness: 160});
          const isBreak = min !== 25;
          // 所有块出齐后，站立块依次「跳」一下
          const hop = isBreak ? Math.max(0, Math.sin(Math.min(1, Math.max(0, (frame - 70 - i * 3) / 14)) * Math.PI)) : 0;
          const bw = unit * min;
          const el = (
            <div key={i}>
              <div
                style={{
                  position: 'absolute',
                  left: x,
                  top: top + r * rowGap - hop * 18,
                  width: bw,
                  height: blockH,
                  borderRadius: Math.min(28, bw / 2),
                  transform: `scaleX(${p})`,
                  transformOrigin: 'left center',
                  background: isBreak
                    ? min === 20
                      ? `linear-gradient(135deg, ${color.warm}, ${color.glow})`
                      : `linear-gradient(135deg, ${color.rose}, ${color.warm})`
                    : color.cold,
                  boxShadow: isBreak ? '0 10px 24px rgba(255,92,138,0.28)' : '0 10px 24px rgba(79,91,255,0.22)',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  left: x,
                  top: top + r * rowGap + blockH + 14,
                  width: bw,
                  textAlign: bw < 60 ? 'center' : 'left',
                  fontFamily: font.rounded,
                  fontWeight: 600,
                  fontSize: 34,
                  color: isBreak ? color.rose : color.inkSoft,
                  opacity: tween(frame, start + 6, start + 20),
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {min}
              </div>
            </div>
          );
          x += bw + gap;
          return el;
        });
      })}
    </>
  );
};

// —— 02 全屏覆盖：三块屏幕同时「日出」 ——
const Screens: React.FC<VisualProps> = ({frame, box, L}) => {
  const k = box.w;
  const screens = pick(L, {
    landscape: [
      {x: 0.0, y: 0.06, w: 0.38},
      {x: 0.62, y: 0.06, w: 0.38},
      {x: 0.28, y: 0.3, w: 0.44, laptop: true},
    ],
    square: [
      {x: 0.0, y: 0.04, w: 0.4},
      {x: 0.6, y: 0.04, w: 0.4},
      {x: 0.27, y: 0.3, w: 0.46, laptop: true},
    ],
    portrait: [
      {x: 0.08, y: 0.02, w: 0.84},
      {x: 0.0, y: 0.56, w: 0.47},
      {x: 0.53, y: 0.56, w: 0.47, laptop: true},
    ],
  });
  return (
    <>
      {screens.map((s, i) => {
        const sw = s.w * k;
        const sh = sw * 0.625;
        const left = box.x + s.x * k;
        const topY = box.y + s.y * k;
        const appear = pop(frame, 6 + i * 6, L.fps, {damping: 18});
        const rise = tween(frame, 34 + i * 4, 62 + i * 4, 0, 1, easeOut);
        const standP = tween(frame, 58 + i * 4, 80 + i * 4, 0, 1, easeOut);
        return (
          <div key={i} style={{opacity: appear, transform: `translateY(${(1 - appear) * 30}px)`}}>
            <div
              style={{
                position: 'absolute',
                left,
                top: topY,
                width: sw,
                height: sh,
                borderRadius: sw * 0.03,
                overflow: 'hidden',
                background: 'linear-gradient(160deg, #27305A, #5A5E92 55%, #A88BAE)',
                boxShadow: `0 0 0 ${sw * 0.018}px #1B1424, 0 20px 40px rgba(80,30,70,0.25)`,
              }}
            >
              <div style={{position: 'absolute', inset: 0, clipPath: `inset(${(1 - rise) * 100}% 0 0 0)`}}>
                <SunriseBackdrop w={sw} h={sh} progress={0.2 + standP * 0.5} sunX={sw * 0.5} sunTopY={sh * 0.62} />
                <Glyph
                  id={`screen-glyph-${i}`}
                  x={sw * 0.5}
                  y={sh * 0.5}
                  size={sh * 0.78}
                  chair={0}
                  shaft={standP}
                  arrow={tween(standP, 0.5, 1)}
                  head={tween(standP, 0.7, 1)}
                  mono={color.cream}
                />
              </div>
            </div>
            {s.laptop ? (
              <div
                style={{
                  position: 'absolute',
                  left: left - sw * 0.08,
                  top: topY + sh + sw * 0.018,
                  width: sw * 1.16,
                  height: sw * 0.035,
                  borderRadius: `0 0 ${sw * 0.03}px ${sw * 0.03}px`,
                  background: '#1B1424',
                }}
              />
            ) : (
              <div
                style={{
                  position: 'absolute',
                  left: left + sw * 0.44,
                  top: topY + sh + sw * 0.018,
                  width: sw * 0.12,
                  height: sw * 0.07,
                  background: '#1B1424',
                  borderRadius: `0 0 ${sw * 0.02}px ${sw * 0.02}px`,
                }}
              />
            )}
          </div>
        );
      })}
    </>
  );
};

// —— 03 睡眠感知：正面看笔记本，盖子向前合上，月亮升起 ——
const Sleep: React.FC<VisualProps> = ({frame, box, L}) => {
  const size = Math.min(box.w, box.h);
  const cx = box.x + box.w / 2;
  const lidW = size * 0.66;
  const lidH = lidW * 0.64;
  const baseY = box.y + box.h * 0.62;
  const close = tween(frame, 14, 42, 0, 1, easeInOut);
  // 盖子绕底边转向观众：0° 打开，-86° 基本合上
  const angle = -86 * close;
  const dim = 0.25 + close * 0.6;
  const moon = pop(frame, 44, L.fps, {damping: 12});
  const ring = tween(frame, 52, 96, 0, 1, easeInOut);
  const R = size * 0.1;
  const moonX = cx;
  const moonY = baseY - lidH - size * 0.02;
  return (
    <>
      {/* 盖子 */}
      <div
        style={{
          position: 'absolute',
          left: cx - lidW / 2,
          top: baseY - lidH,
          width: lidW,
          height: lidH,
          transformOrigin: 'bottom center',
          transform: `perspective(${size * 2.4}px) rotateX(${angle}deg)`,
          borderRadius: `${size * 0.03}px ${size * 0.03}px ${size * 0.006}px ${size * 0.006}px`,
          background: '#1B1424',
          padding: size * 0.016,
          boxSizing: 'border-box',
        }}
      >
        <div style={{position: 'relative', width: '100%', height: '100%', borderRadius: size * 0.012, overflow: 'hidden'}}>
          <SunriseBackdrop w={lidW} h={lidH} progress={0.35} sunX={lidW / 2} sunTopY={lidH * 0.7} />
          <div style={{position: 'absolute', inset: 0, background: `rgba(20,11,36,${dim})`}} />
        </div>
      </div>
      {/* 底座 */}
      <div
        style={{
          position: 'absolute',
          left: cx - lidW * 0.58,
          top: baseY,
          width: lidW * 1.16,
          height: size * 0.035,
          borderRadius: `0 0 ${size * 0.03}px ${size * 0.03}px`,
          background: 'linear-gradient(180deg, #3A2E48, #1B1424)',
        }}
      />
      <svg width={L.width} height={L.height} style={{position: 'absolute', inset: 0, overflow: 'visible'}}>
        {/* 进度环：合盖超过 5 分钟 */}
        <circle cx={moonX} cy={moonY} r={R * 1.6} fill="none" stroke={color.ink} strokeOpacity={0.1 * moon} strokeWidth={size * 0.014} />
        <circle
          cx={moonX}
          cy={moonY}
          r={R * 1.6}
          fill="none"
          stroke={color.warm}
          strokeWidth={size * 0.014}
          strokeLinecap="round"
          pathLength={1}
          strokeDasharray="1 1"
          strokeDashoffset={1 - ring}
          transform={`rotate(-90 ${moonX} ${moonY})`}
          opacity={ring > 0.01 ? 1 : 0}
        />
        {/* 月亮：两圆相减 */}
        <mask id="moon-cut">
          <rect x={0} y={0} width={L.width} height={L.height} fill="white" />
          <circle cx={moonX + R * 0.45} cy={moonY - R * 0.32} r={R * 0.8} fill="black" />
        </mask>
        <g transform={`translate(${moonX} ${moonY}) scale(${moon}) translate(${-moonX} ${-moonY})`}>
          <circle cx={moonX} cy={moonY} r={R} fill={color.rose} mask="url(#moon-cut)" />
        </g>
        {[0, 1, 2].map((i) => {
          const p = tween(frame, 52 + i * 10, 92 + i * 10, 0, 1, (t) => t);
          return (
            <text
              key={i}
              x={moonX + R * (2 + i * 0.5)}
              y={moonY - R * (0.3 + p * 1.2 + i * 0.5)}
              fontFamily={font.rounded}
              fontWeight={700}
              fontSize={size * (0.06 - i * 0.01)}
              fill={color.ink}
              opacity={Math.sin(p * Math.PI)}
            >
              z
            </text>
          );
        })}
        <text
          x={moonX}
          y={baseY + size * 0.14}
          textAnchor="middle"
          fontFamily={font.rounded}
          fontWeight={700}
          fontSize={size * 0.06}
          fill={color.warm}
          opacity={tween(frame, 72, 92)}
        >
          5:00+
        </text>
      </svg>
    </>
  );
};

// —— 04 今日统计：每站起来一次，就多一个小人 ——
const Stats: React.FC<VisualProps> = ({frame, box, L}) => {
  const count = 7;
  const perRow = L.format === 'portrait' ? 4 : 7;
  const cell = Math.min(box.w / perRow, pick(L, {landscape: 150, square: 128, portrait: 230}));
  const glyphSize = cell * 2.3;
  // 字形里小人的中心在画布中心右侧 168/1024 处
  const personOffset = (168 / 1024) * glyphSize;
  const rows = Math.ceil(count / perRow);
  const gridW = cell * perRow;
  const counterH = pick(L, {landscape: 200, square: 180, portrait: 240});
  const top = box.y + (box.h - (counterH + rows * cell)) / 2;
  const popped = Array.from({length: count}).filter((_, i) => frame >= 14 + i * 8).length;
  return (
    <>
      <div style={{position: 'absolute', left: box.x + (box.w - gridW) / 2, top, display: 'flex', alignItems: 'baseline', gap: 20}}>
        <span style={{fontFamily: font.rounded, fontWeight: 700, fontSize: counterH * 0.8, color: color.ink, fontVariantNumeric: 'tabular-nums', lineHeight: 1}}>
          {popped}
        </span>
        <span style={{fontFamily: font.cjk, fontWeight: 600, fontSize: counterH * 0.2, color: color.ink}}>次站立</span>
        <span style={{fontFamily: font.cjk, fontSize: counterH * 0.16, color: color.inkSoft, marginLeft: 16}}>· 8 个番茄</span>
      </div>
      {Array.from({length: count}).map((_, i) => {
        const col = i % perRow;
        const row = Math.floor(i / perRow);
        const p = pop(frame, 14 + i * 8, L.fps, {damping: 11, stiffness: 200});
        return (
          <Glyph
            key={i}
            id={`stat-${i}`}
            x={box.x + (box.w - gridW) / 2 + cell * (col + 0.5) - personOffset}
            y={top + counterH + cell * (row + 0.62)}
            size={glyphSize}
            chair={0}
            head={p}
            shaft={Math.min(1, p * 1.2)}
            arrow={Math.min(1, p * 1.2)}
            sticker={1}
            scale={0.6 + 0.4 * p}
            opacity={Math.min(1, p * 3)}
          />
        );
      })}
    </>
  );
};

const BEATS: {label: string; lines: [string, string]; sub: string; Visual: React.FC<VisualProps>}[] = [
  {label: '01  番茄节奏', lines: ['25 分钟专注', '5 分钟站起来'], sub: '每 4 轮，长休息 20 分钟', Visual: Rhythm},
  {label: '02  全屏覆盖', lines: ['每一块屏幕', '都会提醒你'], sub: '全屏应用、多个 Space 也不例外', Visual: Screens},
  {label: '03  睡眠感知', lines: ['合上电脑', '也算休息'], sub: '合盖超过 5 分钟，醒来开始新番茄', Visual: Sleep},
  {label: '04  今日统计', lines: ['每一次站起来', '都算数'], sub: '番茄数、站立次数，每天记下', Visual: Stats},
];

const Beat: React.FC<{index: number}> = ({index}) => {
  const frame = useCurrentFrame();
  const L = useLayout();
  const {label, lines, sub, Visual} = BEATS[index];
  const head = pick(L, {
    landscape: {x: 140, y: 380, size: 72, w: 520},
    square: {x: 80, y: 96, size: 64, w: 920},
    portrait: {x: 80, y: 360, size: 84, w: 920},
  });
  const box: Rect = pick(L, {
    landscape: {x: 720, y: 200, w: 1060, h: 680},
    square: {x: 80, y: 420, w: 920, h: 560},
    portrait: {x: 60, y: 820, w: 960, h: 880},
  });
  const exit = BEAT - 16;
  const out = tween(frame, exit, BEAT, 0, 1, easeIn);
  return (
    <AbsoluteFill>
      <div style={{position: 'absolute', left: head.x, top: head.y, width: head.w}}>
        <LineReveal start={0} exit={exit} style={{fontFamily: font.rounded, fontWeight: 700, fontSize: head.size * 0.36, color: color.rose, letterSpacing: '0.08em', marginBottom: head.size * 0.3}}>
          {label}
        </LineReveal>
        <div style={{fontFamily: font.cjk, fontWeight: 600, fontSize: head.size, lineHeight: 1.16, color: color.ink}}>
          <LineReveal start={4} exit={exit}>
            {lines[0]}
          </LineReveal>
          <LineReveal start={10} exit={exit + 2}>
            {lines[1]}
          </LineReveal>
        </div>
        <LineReveal start={18} exit={exit + 4} style={{fontFamily: font.cjk, fontSize: head.size * 0.42, color: color.inkSoft, marginTop: head.size * 0.4}}>
          {sub}
        </LineReveal>
      </div>
      <AbsoluteFill style={{opacity: 1 - out, transform: `translateY(${-out * 40}px)`}}>
        <Visual frame={frame} box={box} L={L} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// 04 功能：四个短 beat，每个 BEAT 帧
export const Features: React.FC = () => {
  const frame = useCurrentFrame();
  // 背景从日光的奶油色缓慢过渡到图标的粉色，为结尾做准备
  const shift = tween(frame, 0, BEAT * 4, 0, 1, easeInOut);
  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(180deg, ${color.cream}, rgba(248,227,234,${shift}) 100%), ${color.cream}`,
      }}
    >
      {BEATS.map((_, i) => (
        <Sequence key={i} from={i * BEAT} durationInFrames={BEAT} name={`功能 ${i + 1}`}>
          <Beat index={i} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
