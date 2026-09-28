import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Glyph} from '../components/Glyph';
import {SunriseBackdrop} from '../components/SunriseBackdrop';
import {LineReveal} from '../components/Type';
import {easeIn, easeInOut, easeOut, lerp, mmss, pop, tween} from '../lib/anim';
import {pick, screenRect, useLayout} from '../lib/layout';
import {color, font} from '../theme';
import T from '../timeline.json';

const K = T.sunrise;

// 03 日出：遮罩视觉方向 A 的动态概念稿
export const Sunrise: React.FC = () => {
  const frame = useCurrentFrame();
  const L = useLayout();
  const {fps, width: w, height: h} = L;
  const screen = screenRect(L);

  // —— 进场：夜色先在屏幕里从下往上升起，再推满整个画面 ——
  const wipe = tween(frame, K.wipe, K.wipe + 38, 0, 1, easeOut);
  const expand = tween(frame, K.expand, K.expand + 58, 0, 1, easeInOut);
  const rx = lerp(screen.x, 0, expand);
  const ry = lerp(screen.y, 0, expand);
  const rw = lerp(screen.w, w, expand);
  const rh = lerp(screen.h, h, expand);
  const clipTop = ry + rh * (1 - wipe);
  const radius = lerp(screen.w * 0.022, 0, expand);
  const clip = `inset(${clipTop}px ${w - rx - rw}px ${h - ry - rh}px ${rx}px round ${radius}px)`;
  // 内容跟着镜头推进一起放大，形成「钻进屏幕」的感觉
  const push = lerp(0.9, 1, expand);

  const g = pick(L, {
    landscape: {x: 1330, y: 540, size: 720},
    square: {x: 760, y: 250, size: 460},
    portrait: {x: 520, y: 640, size: 780},
  });
  const text = pick(L, {
    landscape: {x: 140, y: 250, head: 128, sub: 36, timer: 92, actionsY: 920},
    square: {x: 80, y: 430, head: 92, sub: 30, timer: 72, actionsY: 900},
    portrait: {x: 80, y: 1130, head: 136, sub: 38, timer: 96, actionsY: 1760},
  });

  // —— 站起来：椅子被推开，身体向上画出，头「冒」出来，颜色由冷转暖 ——
  const chairIn = tween(frame, K.chairIn, K.chairIn + 40, 0, 1, easeInOut);
  const shaft = tween(frame, K.stand, K.stand + 34, 0, 1, easeOut);
  const arrow = tween(frame, K.stand + 24, K.stand + 46, 0, 1, easeOut);
  const head = pop(frame, K.headPop, fps, {damping: 10, stiffness: 190});
  const tilt = -7 * pop(frame, K.stand + 6, fps, {damping: 16, stiffness: 120});
  const warmth = tween(frame, K.stand, K.stand + 90, 0, 1, easeInOut);
  const stickerP = tween(frame, K.headPop + 6, K.headPop + 26);
  // 站定后轻微的呼吸感
  const breathe = frame > K.headPop + 40 ? Math.sin((frame - K.headPop) / 34) * 6 : 0;

  // —— 休息倒计时：5 分钟快进，太阳随之升起 ——
  const lapse = tween(frame, K.lapseStart, K.lapseEnd, 0, 1, (t) => t);
  const sunProgress = 0.1 + 0.9 * tween(frame, K.lapseStart - 40, K.lapseEnd, 0, 1, easeInOut);
  const seconds = 5 * 60 * (1 - lapse);
  const sunX = g.x + ((680 - 512) / 1024) * g.size;
  const sunTopY = g.y + g.size * 0.26;

  // —— 收尾：日光铺满画面，过渡到下一段的奶油色背景 ——
  const finale = tween(frame, K.finale, K.finale + 36, 0, 1, easeIn);
  const flood = Math.hypot(w, h) * 1.1 * finale;
  const contentOut = tween(frame, K.finale - 6, K.finale + 16, 0, 1, easeIn);

  const actions = tween(frame, K.lapseStart + 20, K.lapseStart + 50);

  return (
    // 底色设为夜色：push 缩放后露出的边缘不会穿帮
    <AbsoluteFill style={{clipPath: clip, background: color.night}}>
      <AbsoluteFill style={{transform: `scale(${push})`}}>
        <SunriseBackdrop w={w} h={h} progress={sunProgress * tween(frame, K.chairIn - 20, K.chairIn + 40)} sunX={sunX} sunTopY={sunTopY} />

        <div style={{position: 'absolute', inset: 0, opacity: 1 - contentOut}}>
          <Glyph
            id="sunrise-glyph"
            x={g.x}
            y={g.y + breathe * 0.3}
            size={g.size}
            chair={chairIn}
            shaft={shaft}
            arrow={arrow}
            head={head}
            tilt={tilt}
            warmth={warmth}
            sticker={stickerP}
            lift={breathe}
          />

          <div style={{position: 'absolute', left: text.x, top: text.y, color: color.cream}}>
            <div style={{fontFamily: font.cjk, fontWeight: 600, fontSize: text.head, lineHeight: 1.12, letterSpacing: '0.01em'}}>
              <LineReveal start={K.headline}>站起来，</LineReveal>
              <LineReveal start={K.headline + 8}>活动一下</LineReveal>
            </div>
            <LineReveal start={K.headline + 26} style={{marginTop: text.sub * 0.9}}>
              <span style={{fontFamily: font.cjk, fontSize: text.sub, color: color.moonlight}}>离开屏幕，伸展身体，看看远处</span>
            </LineReveal>
            <LineReveal start={K.lapseStart - 16} style={{marginTop: text.sub * 1.3}}>
              <span style={{display: 'inline-flex', alignItems: 'baseline', gap: text.sub * 0.6}}>
                <span
                  style={{
                    fontFamily: font.rounded,
                    fontWeight: 300,
                    fontSize: text.timer,
                    fontVariantNumeric: 'tabular-nums',
                    letterSpacing: '-0.02em',
                  }}
                >
                  {mmss(seconds)}
                </span>
                <span style={{fontFamily: font.cjk, fontSize: text.sub * 0.8, color: color.moonlight}}>后回到工作</span>
              </span>
            </LineReveal>
          </div>

          {/* 操作：推迟是次要按钮，跳过需要长按，避免误触 */}
          <div
            style={{
              position: 'absolute',
              left: text.x,
              top: text.actionsY,
              display: 'flex',
              alignItems: 'center',
              gap: text.sub * 1.1,
              opacity: actions,
              transform: `translateY(${(1 - actions) * 16}px)`,
              fontFamily: font.cjk,
              fontSize: text.sub * 0.78,
            }}
          >
            <div
              style={{
                border: `2px solid rgba(255,244,236,0.4)`,
                borderRadius: 999,
                padding: `${text.sub * 0.36}px ${text.sub * 0.8}px`,
                color: color.cream,
              }}
            >
              推迟 5 分钟
            </div>
            <div style={{color: color.moonlight, display: 'flex', alignItems: 'center', gap: text.sub * 0.3}}>
              <span
                style={{
                  fontFamily: font.text,
                  fontSize: text.sub * 0.6,
                  border: `1.5px solid ${color.moonlight}`,
                  borderRadius: 6,
                  padding: `1px ${text.sub * 0.2}px`,
                }}
              >
                esc
              </span>
              长按跳过
            </div>
          </div>
        </div>

        {/* 日光铺满 */}
        {finale > 0 ? (
          <div
            style={{
              position: 'absolute',
              left: sunX - flood,
              top: sunTopY - flood,
              width: flood * 2,
              height: flood * 2,
              borderRadius: '50%',
              background: `radial-gradient(circle, ${color.cream} 0%, ${color.cream} 62%, rgba(255,196,138,0.9) 80%, rgba(255,164,110,0) 100%)`,
            }}
          />
        ) : null}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
