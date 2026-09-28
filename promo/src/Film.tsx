import React from 'react';
import {AbsoluteFill, Html5Audio, Sequence, staticFile} from 'remotion';
import {Grain} from './components/Grain';
import {Features} from './scenes/Features';
import {Intro} from './scenes/Intro';
import {Outro} from './scenes/Outro';
import {Sunrise} from './scenes/Sunrise';
import {color} from './theme';
import T from './timeline.json';

const S = T.scenes;

// 整片：场景按时间叠放，后出场的在上层，重叠的帧就是转场
export const Film: React.FC = () => (
  <AbsoluteFill style={{background: color.paperBottom}}>
    <Sequence from={S.intro.from} durationInFrames={S.intro.dur} name="01 坐着 · 菜单栏">
      <Intro />
    </Sequence>
    <Sequence from={S.sunrise.from} durationInFrames={S.sunrise.dur} name="02 日出">
      <Sunrise />
    </Sequence>
    <Sequence from={S.features.from} durationInFrames={S.features.dur} name="03 功能">
      <Features />
    </Sequence>
    <Sequence from={S.outro.from} durationInFrames={S.outro.dur} name="04 收尾">
      <Outro />
    </Sequence>
    <Grain />
    {/* 音效由 scripts/make-sfx.py 按 timeline.json 合成，运行 pnpm sfx 生成 */}
    <Html5Audio src={staticFile('sfx/soundtrack.wav')} />
  </AbsoluteFill>
);
