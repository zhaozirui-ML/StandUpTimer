import {Easing, interpolate, spring} from 'remotion';

// 指数型减速：进场用，干脆利落地停住
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
// 对称的加减速：镜头运动、形变用
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
// 加速离场
export const easeIn = Easing.bezier(0.55, 0, 1, 0.45);

export const tween = (
  frame: number,
  start: number,
  end: number,
  from = 0,
  to = 1,
  easing: (t: number) => number = easeOut,
) =>
  interpolate(frame, [start, end], [from, to], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing,
  });

type SpringOpts = {damping?: number; stiffness?: number; mass?: number};

// 带一点点过冲的弹簧，用于「贴上去」「冒出来」这类动作；阻尼偏高，避免廉价的回弹感
export const pop = (frame: number, start: number, fps: number, opts: SpringOpts = {}) =>
  spring({
    frame: frame - start,
    fps,
    config: {damping: 14, stiffness: 170, mass: 0.8, ...opts},
  });

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export const clamp01 = (v: number) => Math.max(0, Math.min(1, v));

export const mmss = (seconds: number) => {
  const total = Math.max(0, Math.ceil(seconds));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
};
