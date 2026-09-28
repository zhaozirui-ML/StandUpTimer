import React from 'react';
import {interpolateColors} from 'remotion';
import {lerp} from '../lib/anim';
import {color} from '../theme';

// 「日出」遮罩的背景：夜色底 + 从地平线升起的太阳。progress 0..1 对应休息进度
export const SunriseBackdrop: React.FC<{
  w: number;
  h: number;
  progress: number;
  sunX: number;
  // 太阳完全升起时圆心所在高度
  sunTopY: number;
}> = ({w, h, progress, sunX, sunTopY}) => {
  const top = interpolateColors(progress, [0, 1], [color.night, '#2B1239']);
  const bottom = interpolateColors(progress, [0, 1], [color.dusk, '#7A2A4C']);
  const r = Math.max(w, h) * 0.3;
  const sunY = lerp(h + r * 0.55, sunTopY, progress);
  const horizon = 0.25 + progress * 0.55;
  return (
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden', background: `linear-gradient(180deg, ${top}, ${bottom})`}}>
      {/* 地平线的暖光，随进度变亮 */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: h * 0.6,
          background: `linear-gradient(0deg, rgba(232,86,126,${horizon}), rgba(232,86,126,0))`,
        }}
      />
      {/* 太阳：外圈柔光 + 内核 */}
      <div
        style={{
          position: 'absolute',
          left: sunX - r * 1.6,
          top: sunY - r * 1.6,
          width: r * 3.2,
          height: r * 3.2,
          borderRadius: '50%',
          background: `radial-gradient(circle, rgba(255,164,110,${0.35 + progress * 0.25}) 0%, rgba(232,86,126,0.18) 38%, rgba(232,86,126,0) 70%)`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: sunX - r * 0.5,
          top: sunY - r * 0.5,
          width: r,
          height: r,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${color.glow} 0%, rgba(255,162,77,0.85) 30%, rgba(232,86,126,0.45) 55%, rgba(232,86,126,0) 70%)`,
        }}
      />
    </div>
  );
};
