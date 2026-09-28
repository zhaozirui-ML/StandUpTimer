import React from 'react';
import {interpolateColors, random} from 'remotion';
import {clamp01, tween} from '../lib/anim';
import {menuBarH, Rect, STATUS_GLYPH_X} from '../lib/layout';
import {color, font} from '../theme';
import {Glyph} from './Glyph';

// 风格化的 macOS 桌面：只保留能被认出来的结构，不复刻任何具体软件
type Props = {
  rect: Rect;
  // 专注时间流逝进度 0..1，驱动窗口里的「工作量」
  lapse: number;
  // 用于光标等持续的小动作
  frame: number;
  timer: string;
  clock: string;
  // 菜单栏图标的小人部分绘制进度（椅子飞入后再冒出小人）
  statusPerson: number;
  statusChair: boolean;
  statusTimer: number;
  // 到点时菜单栏图标变暖
  alarm: number;
};

const Win: React.FC<{
  W: number;
  x: number;
  y: number;
  w: number;
  h: number;
  dark?: boolean;
  children?: React.ReactNode;
}> = ({W, x, y, w, h, dark, children}) => {
  const bar = W * 0.024;
  const dot = W * 0.0048;
  return (
    <div
      style={{
        position: 'absolute',
        left: x * W,
        top: y * W,
        width: w * W,
        height: h * W,
        borderRadius: W * 0.009,
        background: dark ? '#1E1B2E' : '#FBF8FB',
        boxShadow: `0 ${W * 0.012}px ${W * 0.03}px rgba(20,11,36,0.35), 0 0 0 1px rgba(255,255,255,${dark ? 0.08 : 0.5})`,
        overflow: 'hidden',
      }}
    >
      <div style={{height: bar, display: 'flex', alignItems: 'center', gap: dot * 1.1, paddingLeft: W * 0.01}}>
        {['#FF6159', '#FFBD2E', '#28C941'].map((c) => (
          <div key={c} style={{width: dot * 2, height: dot * 2, borderRadius: '50%', background: c}} />
        ))}
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: bar, bottom: 0}}>{children}</div>
    </div>
  );
};

const CODE_COLORS = ['#FF7AA2', '#8C93FF', '#FFB36B', '#C9C3DD', '#7FD6C2'];

const Editor: React.FC<{W: number; lapse: number}> = ({W, lapse}) => {
  const rows = 15;
  const visible = 3 + lapse * (rows - 3);
  return (
    <div style={{padding: `${W * 0.012}px ${W * 0.016}px`}}>
      {Array.from({length: rows}).map((_, i) => {
        const grow = clamp01(visible - i);
        if (grow <= 0) return null;
        const indent = Math.floor(random(`indent-${i}`) * 3);
        const parts = 1 + Math.floor(random(`parts-${i}`) * 3);
        return (
          <div key={i} style={{display: 'flex', gap: W * 0.006, height: W * 0.014, marginBottom: W * 0.009, paddingLeft: indent * W * 0.018}}>
            {Array.from({length: parts}).map((__, j) => (
              <div
                key={j}
                style={{
                  width: W * (0.03 + random(`w-${i}-${j}`) * 0.09) * clamp01(grow * parts - j),
                  borderRadius: W * 0.004,
                  background: CODE_COLORS[Math.floor(random(`c-${i}-${j}`) * CODE_COLORS.length)],
                  opacity: 0.85,
                }}
              />
            ))}
          </div>
        );
      })}
    </div>
  );
};

// 画布窗口里正在「设计」的，正是这个 App 的图标：一个给作品集准备的小彩蛋
const Canvas: React.FC<{W: number; lapse: number}> = ({W, lapse}) => {
  const board = W * 0.2;
  return (
    <div style={{position: 'absolute', inset: 0, background: '#EEEAF0'}}>
      <div
        style={{
          position: 'absolute',
          left: W * 0.16,
          top: W * 0.05,
          width: board,
          height: board,
          background: '#FFFFFF',
          boxShadow: '0 2px 10px rgba(42,20,51,0.08)',
        }}
      >
        <Glyph
          id="canvas-glyph"
          x={board / 2}
          y={board / 2}
          size={board}
          base={tween(lapse, 0, 0.15)}
          chair={tween(lapse, 0.12, 0.4)}
          shaft={tween(lapse, 0.4, 0.55)}
          arrow={tween(lapse, 0.52, 0.64)}
          head={tween(lapse, 0.62, 0.7)}
          sticker={tween(lapse, 0.75, 0.9)}
        />
        {/* 选中框 */}
        <div
          style={{
            position: 'absolute',
            inset: -W * 0.004,
            border: `${Math.max(1, W * 0.0012)}px solid #4F8BFF`,
            opacity: lapse > 0.05 ? 1 : 0,
          }}
        />
      </div>
      {/* 左侧图层面板 */}
      <div style={{position: 'absolute', left: 0, top: 0, bottom: 0, width: W * 0.1, background: '#F8F6F9', borderRight: '1px solid #E4DEE6'}}>
        {Array.from({length: 7}).map((_, i) => (
          <div
            key={i}
            style={{
              margin: `${W * 0.009}px ${W * 0.01}px`,
              height: W * 0.008,
              width: W * (0.04 + random(`layer-${i}`) * 0.04),
              borderRadius: W * 0.003,
              background: i === 2 ? '#4F8BFF' : '#D9D2DD',
            }}
          />
        ))}
      </div>
    </div>
  );
};

const Chat: React.FC<{W: number; lapse: number}> = ({W, lapse}) => {
  const bubbles = [
    {at: 0.12, me: false, w: 0.12},
    {at: 0.3, me: true, w: 0.09},
    {at: 0.5, me: false, w: 0.15},
    {at: 0.72, me: true, w: 0.11},
  ];
  return (
    <div style={{padding: W * 0.012, display: 'flex', flexDirection: 'column', gap: W * 0.008}}>
      {bubbles.map((b, i) => {
        const p = tween(lapse, b.at, b.at + 0.06);
        return (
          <div
            key={i}
            style={{
              alignSelf: b.me ? 'flex-end' : 'flex-start',
              width: W * b.w,
              height: W * 0.022,
              borderRadius: W * 0.011,
              background: b.me ? color.cold : '#E7E1EA',
              opacity: p,
              transform: `translateY(${(1 - p) * W * 0.01}px) scale(${0.9 + p * 0.1})`,
            }}
          />
        );
      })}
    </div>
  );
};

export const Desktop: React.FC<Props> = ({rect, lapse, frame, timer, clock, statusPerson, statusChair, statusTimer, alarm}) => {
  const W = rect.w;
  const mb = menuBarH(W);
  const itemColor = interpolateColors(alarm, [0, 1], [color.ink, '#E0445F']);
  const t = frame / 60;
  const cursorX = W * (0.5 + 0.28 * Math.sin(t * 1.7));
  const cursorY = W * (0.3 + 0.12 * Math.sin(t * 2.3 + 1));
  const menuText: React.CSSProperties = {fontFamily: font.text, fontSize: mb * 0.44, color: color.ink, fontWeight: 500};

  return (
    <div
      style={{
        position: 'absolute',
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        borderRadius: W * 0.022,
        overflow: 'hidden',
        background: 'linear-gradient(160deg, #27305A 0%, #5A5E92 55%, #A88BAE 100%)',
        boxShadow: `0 0 0 ${W * 0.009}px #1B1424, 0 ${W * 0.04}px ${W * 0.08}px rgba(80,30,70,0.28)`,
      }}
    >
      <Win W={W} x={0.05} y={0.075} w={0.46} h={0.4} dark>
        <Editor W={W} lapse={lapse} />
      </Win>
      <Win W={W} x={0.36} y={0.13} w={0.52} h={0.36}>
        <Canvas W={W} lapse={lapse} />
      </Win>
      <Win W={W} x={0.67} y={0.33} w={0.26} h={0.22}>
        <Chat W={W} lapse={lapse} />
      </Win>

      {/* 光标只在专注时间流逝时出现 */}
      <svg
        width={W * 0.018}
        height={W * 0.026}
        viewBox="0 0 18 26"
        style={{position: 'absolute', left: cursorX, top: cursorY, opacity: lapse > 0 && lapse < 1 ? 1 : 0}}
      >
        <path d="M1 1 L1 21 L6 16 L10 25 L13 24 L9 15 L16 15 Z" fill="#FFFFFF" stroke="#140B24" strokeWidth="1.5" strokeLinejoin="round" />
      </svg>

      {/* 菜单栏 */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          right: 0,
          height: mb,
          background: 'rgba(246,238,246,0.82)',
          display: 'flex',
          alignItems: 'center',
          paddingLeft: W * 0.018,
          gap: W * 0.022,
          ...menuText,
        }}
      >
        <div style={{width: mb * 0.42, height: mb * 0.42, borderRadius: '50%', background: color.ink}} />
        {['访达', '文件', '编辑', '显示', '前往', '窗口'].map((m, i) => (
          <span key={m} style={{fontWeight: i === 0 ? 700 : 500}}>
            {m}
          </span>
        ))}
      </div>
      {/* 菜单栏右侧：系统图标 + 时钟 */}
      <div style={{position: 'absolute', top: 0, height: mb, right: W * 0.018, display: 'flex', alignItems: 'center', gap: W * 0.018, ...menuText}}>
        <svg width={mb * 0.62} height={mb * 0.34} viewBox="0 0 26 14">
          <rect x="0.75" y="0.75" width="21" height="12.5" rx="3.5" fill="none" stroke={color.ink} strokeWidth="1.5" />
          <rect x="3" y="3" width="15" height="8" rx="1.8" fill={color.ink} />
          <rect x="23" y="4.5" width="2" height="5" rx="1" fill={color.ink} />
        </svg>
        <svg width={mb * 0.5} height={mb * 0.4} viewBox="0 0 20 16">
          <path d="M1 5.5 A13 13 0 0 1 19 5.5" fill="none" stroke={color.ink} strokeWidth="2" strokeLinecap="round" />
          <path d="M4.5 9 A8 8 0 0 1 15.5 9" fill="none" stroke={color.ink} strokeWidth="2" strokeLinecap="round" />
          <circle cx="10" cy="13" r="1.8" fill={color.ink} />
        </svg>
        <span style={{fontVariantNumeric: 'tabular-nums'}}>{clock}</span>
      </div>

      {/* StandUpTimer 的菜单栏图标：单色 template 字形 + 等宽数字倒计时 */}
      {statusChair ? (
        <Glyph
          id="status-glyph"
          x={W * STATUS_GLYPH_X}
          y={mb / 2}
          size={mb * 1.5}
          mono={itemColor}
          shaft={statusPerson}
          arrow={tween(statusPerson, 0.5, 1)}
          head={tween(statusPerson, 0.7, 1)}
        />
      ) : null}
      <div
        style={{
          position: 'absolute',
          left: W * STATUS_GLYPH_X + mb * 0.62,
          top: 0,
          height: mb,
          display: 'flex',
          alignItems: 'center',
          ...menuText,
          color: itemColor,
          fontVariantNumeric: 'tabular-nums',
          opacity: statusTimer,
          transform: `translateX(${(1 - statusTimer) * -mb * 0.4}px)`,
        }}
      >
        {timer}
      </div>
    </div>
  );
};
