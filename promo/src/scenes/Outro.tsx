import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Glyph} from '../components/Glyph';
import {Chars, LineReveal} from '../components/Type';
import {easeInOut, pop, tween} from '../lib/anim';
import {pick, useLayout} from '../lib/layout';
import {color, font} from '../theme';
import T from '../timeline.json';

const K = T.outro;

// 05 收尾：图标一笔一笔画出来，最后像贴纸一样「啪」地贴上
export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const L = useLayout();
  const {fps} = L;

  const bgIn = tween(frame, 0, 22);
  const base = pop(frame, K.base, fps, {damping: 15, stiffness: 140});
  const chair = tween(frame, K.draw, K.draw + 36, 0, 1, easeInOut);
  const shaft = tween(frame, K.draw + 26, K.draw + 50);
  const arrow = tween(frame, K.draw + 42, K.draw + 60);
  const head = pop(frame, K.draw + 54, fps, {damping: 10, stiffness: 200});
  // 贴纸：白边瞬间出现 + 整体从略大、略歪的状态压下去
  const slap = pop(frame, K.slap, fps, {damping: 12, stiffness: 260});
  const slapped = frame >= K.slap;
  const sticker = slapped ? Math.min(1, (frame - K.slap) / 4) : 0;
  const iconScale = slapped ? 1.1 - 0.1 * slap : 1;
  const iconRotate = slapped ? -4 * (1 - slap) : 0;

  const lock = pick(L, {
    landscape: {icon: {x: 480, y: 500, size: 520}, word: {x: 740, y: 372, size: 132, align: 'left' as const}, tag: 46, url: {y: 972}},
    square: {icon: {x: 540, y: 380, size: 480}, word: {x: 0, y: 640, size: 108, align: 'center' as const}, tag: 42, url: {y: 990}},
    portrait: {icon: {x: 540, y: 740, size: 640}, word: {x: 0, y: 1090, size: 128, align: 'center' as const}, tag: 50, url: {y: 1790}},
  });
  const centered = lock.word.align === 'center';

  return (
    <AbsoluteFill style={{opacity: bgIn, background: `linear-gradient(180deg, ${color.paperTop}, ${color.paperBottom})`}}>
      <Glyph
        id="outro-icon"
        x={lock.icon.x}
        y={lock.icon.y}
        size={lock.icon.size}
        base={base}
        chair={chair}
        shaft={shaft}
        arrow={arrow}
        head={head}
        sticker={sticker}
        scale={iconScale}
        rotate={iconRotate}
      />
      <div
        style={{
          position: 'absolute',
          left: centered ? 0 : lock.word.x,
          right: centered ? 0 : undefined,
          top: lock.word.y,
          textAlign: lock.word.align,
          color: color.ink,
        }}
      >
        <div style={{fontFamily: font.rounded, fontWeight: 700, fontSize: lock.word.size, letterSpacing: '-0.02em', lineHeight: 1.05}}>
          <Chars text="StandUpTimer" start={K.word} stagger={2} />
        </div>
        <LineReveal start={K.word + 18} style={{fontFamily: font.cjk, fontWeight: 500, fontSize: lock.tag, color: color.inkSoft, marginTop: lock.tag * 0.5}}>
          每 25 分钟，站起来一次
        </LineReveal>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: lock.url.y,
          textAlign: 'center',
          fontFamily: font.text,
          fontWeight: 500,
          fontSize: 26,
          letterSpacing: '0.02em',
          color: color.inkSoft,
          opacity: tween(frame, K.word + 40, K.word + 64),
        }}
      >
        macOS 菜单栏小工具 · github.com/zhaozirui-ML/StandUpTimer
      </div>
    </AbsoluteFill>
  );
};
