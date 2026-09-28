import React from 'react';
import {useCurrentFrame} from 'remotion';
import {easeIn, easeOut, tween} from '../lib/anim';

// 整行从遮罩下方升起；exit 给出时整行向上淡出
export const LineReveal: React.FC<{
  start: number;
  exit?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
  duration?: number;
}> = ({start, exit, children, style, duration = 34}) => {
  const frame = useCurrentFrame();
  const inP = tween(frame, start, start + duration, 0, 1, easeOut);
  const outP = exit === undefined ? 0 : tween(frame, exit, exit + 18, 0, 1, easeIn);
  return (
    <div style={{overflow: 'hidden', paddingBottom: '0.12em', marginBottom: '-0.12em', ...style}}>
      <div
        style={{
          transform: `translateY(${(1 - inP) * 105 - outP * 60}%)`,
          opacity: Math.min(inP * 1.4, 1) * (1 - outP),
          whiteSpace: 'nowrap',
        }}
      >
        {children}
      </div>
    </div>
  );
};

// 逐字出现，用于字标和短句
export const Chars: React.FC<{
  text: string;
  start: number;
  stagger?: number;
  style?: React.CSSProperties;
}> = ({text, start, stagger = 2, style}) => {
  const frame = useCurrentFrame();
  return (
    <span style={{display: 'inline-flex', whiteSpace: 'pre', ...style}}>
      {Array.from(text).map((ch, i) => {
        const p = tween(frame, start + i * stagger, start + i * stagger + 26, 0, 1, easeOut);
        return (
          <span
            key={i}
            style={{display: 'inline-block', transform: `translateY(${(1 - p) * 0.45}em)`, opacity: p}}
          >
            {ch}
          </span>
        );
      })}
    </span>
  );
};
