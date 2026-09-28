import React from 'react';
import {AbsoluteFill, interpolateColors, useCurrentFrame} from 'remotion';
import {Desktop} from '../components/Desktop';
import {Glyph} from '../components/Glyph';
import {LineReveal} from '../components/Type';
import {easeIn, easeInOut, easeOut, lerp, mmss, pop, tween} from '../lib/anim';
import {pick, screenRect, statusGlyphSize, statusPoint, useLayout} from '../lib/layout';
import {color, font} from '../theme';
import T from '../timeline.json';

const K = T.intro;

// 01 坐着 → 02 菜单栏里的番茄钟
export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const L = useLayout();
  const {fps} = L;
  const screen = screenRect(L);
  const sp = statusPoint(L);

  // —— 开场：一把椅子，和一个不断变大的数字 ——
  const home = pick(L, {
    landscape: {x: 1400, y: 560, size: 1000},
    square: {x: 700, y: 360, size: 800},
    portrait: {x: 640, y: 700, size: 1100},
  });
  const text = pick(L, {
    landscape: {x: 140, y: 380, big: 200, small: 64, label: 42},
    square: {x: 80, y: 690, big: 170, small: 56, label: 38},
    portrait: {x: 80, y: 1200, big: 210, small: 68, label: 44},
  });
  const draw = tween(frame, K.chairDraw, K.chairDraw + 60, 0, 1, easeInOut);
  const stickerIn = tween(frame, K.chairDraw + 44, K.chairDraw + 70);
  const minutes = Math.round(tween(frame, K.counterStart, K.counterEnd, 0, 192, easeOut));
  const landing = pop(frame, K.counterEnd, fps, {damping: 11});
  const counterScale = frame < K.counterEnd ? 1 : 1 + (1 - landing) * 0.06;
  // 坐久了：椅子被压得往下沉一点
  const slump = tween(frame, K.slump, K.slump + 36, 0, 1, easeInOut);
  const textOut = tween(frame, K.flyStart - 14, K.flyStart + 8, 0, 1, easeIn);

  // —— 转场：椅子缩小飞进菜单栏，桌面从它身后拉远出现 ——
  const fly = tween(frame, K.flyStart, K.flyEnd, 0, 1, easeInOut);
  const landed = frame >= K.flyEnd;
  const chairX = lerp(home.x, sp.x, fly);
  const chairY = lerp(home.y + slump * 14, sp.y, fly);
  // 尺寸按指数插值，缩小过程在视觉上才是匀速的
  const chairSize = home.size * Math.pow(statusGlyphSize(L) / home.size, fly);
  const zoom = lerp(2.8, 1, tween(frame, K.flyStart + 8, K.flyEnd + 6, 0, 1, easeInOut));
  const desktopIn = tween(frame, K.flyStart + 10, K.flyStart + 44);

  // —— 专注：时间快进 ——
  const lapse = tween(frame, K.lapseStart, K.lapseEnd, 0, 1, (t) => t * t * (1.6 - 0.6 * t));
  const seconds = 25 * 60 * (1 - lapse);
  const alarm = tween(frame, K.alarm - 4, K.alarm + 8);
  const clockMin = Math.floor(lapse * 25);
  const clock = `周一 10:${String(clockMin).padStart(2, '0')}`;
  const person = tween(frame, K.personPop, K.personPop + 22, 0, 1, easeOut);
  const timerIn = tween(frame, K.personPop + 8, K.personPop + 30);

  // —— 放大提示框：把菜单栏里那一小块拿出来给观众看 ——
  const callout = pick(L, {
    landscape: {x: sp.x - 10, y: sp.y + 84, fs: 64},
    square: {x: sp.x - 40, y: sp.y + 76, fs: 58},
    portrait: {x: 540, y: 1500, fs: 112},
  });
  const calloutP = pop(frame, K.calloutIn, fps, {damping: 15, stiffness: 150});
  const sinceAlarm = frame - K.alarm;
  const pulse = sinceAlarm >= 0 ? 1 + 0.08 * Math.max(0, Math.sin((sinceAlarm / 18) * Math.PI)) * Math.exp(-sinceAlarm / 40) : 1;
  const calloutBg = interpolateColors(alarm, [0, 1], ['#FFFBFC', color.rose]);
  const calloutInk = interpolateColors(alarm, [0, 1], [color.ink, color.cream]);

  const caption = pick(L, {
    landscape: {x: 140, y: 410, size: 58},
    square: {x: 80, y: 120, size: 60},
    portrait: {x: 60, y: 440, size: 76},
  });
  const captionStyle: React.CSSProperties = {
    position: 'absolute',
    left: caption.x,
    top: caption.y,
    fontFamily: font.rounded,
    fontWeight: 700,
    fontSize: caption.size,
    lineHeight: 1.18,
    color: color.ink,
    letterSpacing: '-0.01em',
  };
  const ccStart = K.calloutIn + 10;

  return (
    <AbsoluteFill style={{background: `linear-gradient(180deg, ${color.paperTop}, ${color.paperBottom})`}}>
      {/* 桌面 */}
      {frame >= K.flyStart ? (
        <AbsoluteFill style={{transform: `scale(${zoom})`, transformOrigin: `${sp.x}px ${sp.y}px`, opacity: desktopIn}}>
          <Desktop
            rect={screen}
            lapse={lapse}
            frame={frame}
            timer={mmss(seconds)}
            clock={clock}
            statusChair={landed}
            statusPerson={person}
            statusTimer={timerIn}
            alarm={alarm}
          />
        </AbsoluteFill>
      ) : null}

      {/* 开场文字 */}
      {frame < K.flyStart + 10 ? (
        <div style={{position: 'absolute', left: text.x, top: text.y, opacity: 1 - textOut, transform: `translateY(${-textOut * 30}px)`}}>
          <LineReveal start={K.counterStart - 30} style={{fontFamily: font.cjk, fontSize: text.label, fontWeight: 500, color: color.inkSoft}}>
            今天，你已经坐了
          </LineReveal>
          <LineReveal start={K.counterStart - 18}>
            <div
              style={{
                fontFamily: font.rounded,
                fontWeight: 700,
                color: color.ink,
                fontVariantNumeric: 'tabular-nums',
                letterSpacing: '-0.03em',
                transform: `scale(${counterScale})`,
                transformOrigin: 'left center',
                display: 'flex',
                alignItems: 'baseline',
                gap: text.small * 0.25,
              }}
            >
              <span style={{fontSize: text.big}}>{Math.floor(minutes / 60)}</span>
              <span style={{fontSize: text.small, fontFamily: font.cjk, fontWeight: 600, marginRight: text.small * 0.3}}>小时</span>
              <span style={{fontSize: text.big}}>{String(minutes % 60).padStart(2, '0')}</span>
              <span style={{fontSize: text.small, fontFamily: font.cjk, fontWeight: 600}}>分钟</span>
            </div>
          </LineReveal>
        </div>
      ) : null}

      {/* 椅子：开场主角，随后飞进菜单栏变成图标的一部分 */}
      {!landed ? (
        <Glyph
          id="intro-chair"
          x={chairX}
          y={chairY}
          size={chairSize}
          chair={draw}
          shaft={0}
          arrow={0}
          head={0}
          sticker={stickerIn * (1 - tween(frame, K.flyStart, K.flyStart + 30))}
          warmth={0}
          mono={fly > 0.55 ? interpolateColors(fly, [0.55, 1], [color.cold, color.ink]) : undefined}
          scale={1 - slump * 0.03 * (1 - fly)}
        />
      ) : null}

      {/* 桌面阶段的说明文字：两组文案在同一位置接力 */}
      {frame >= ccStart && frame < K.captionSwap + 24 ? (
        <div style={captionStyle}>
          <LineReveal start={ccStart} exit={K.captionSwap}>
            StandUpTimer
          </LineReveal>
          <LineReveal start={ccStart + 6} exit={K.captionSwap + 3}>
            住在你的菜单栏
          </LineReveal>
        </div>
      ) : null}
      {frame >= K.captionSwap + 12 ? (
        <div style={captionStyle}>
          <LineReveal start={K.captionSwap + 12}>专心工作</LineReveal>
          <LineReveal start={K.captionSwap + 18}>
            <span style={{color: color.cold}}>25</span> 分钟
          </LineReveal>
        </div>
      ) : null}

      {/* 放大提示框 + 引线 */}
      {frame >= K.calloutIn ? (
        <>
          <svg width={L.width} height={L.height} style={{position: 'absolute', inset: 0, opacity: calloutP}}>
            <line
              x1={sp.x}
              y1={sp.y + statusGlyphSize(L) * 0.62}
              x2={callout.x}
              y2={callout.y}
              stroke={color.ink}
              strokeOpacity={0.4}
              strokeWidth={2}
              strokeDasharray="4 6"
            />
            <circle cx={sp.x} cy={sp.y} r={statusGlyphSize(L) * 0.62} fill="none" stroke={color.ink} strokeOpacity={0.55} strokeWidth={2} />
          </svg>
          <div
            style={{
              position: 'absolute',
              left: callout.x,
              top: callout.y,
              transform: `translateX(-50%) scale(${calloutP * pulse})`,
              transformOrigin: 'top center',
              background: calloutBg,
              borderRadius: 999,
              padding: `${callout.fs * 0.26}px ${callout.fs * 0.5}px ${callout.fs * 0.26}px ${callout.fs * 0.3}px`,
              display: 'flex',
              alignItems: 'center',
              gap: callout.fs * 0.16,
              boxShadow: `0 ${callout.fs * 0.3}px ${callout.fs * 0.8}px rgba(42,20,51,0.28)`,
            }}
          >
            <div style={{position: 'relative', width: callout.fs * 1.2, height: callout.fs * 1.2}}>
              <Glyph id="callout-glyph" x={callout.fs * 0.6} y={callout.fs * 0.6} size={callout.fs * 1.9} mono={calloutInk} />
            </div>
            <span
              style={{
                fontFamily: font.rounded,
                fontWeight: 600,
                fontSize: callout.fs,
                color: calloutInk,
                fontVariantNumeric: 'tabular-nums',
                letterSpacing: '-0.01em',
              }}
            >
              {mmss(seconds)}
            </span>
          </div>
        </>
      ) : null}
    </AbsoluteFill>
  );
};
