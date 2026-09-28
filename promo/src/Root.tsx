import React from 'react';
import {Composition, Folder} from 'remotion';
import {Film} from './Film';
import T from './timeline.json';

const FORMATS = [
  {id: 'Landscape', width: 1920, height: 1080},
  {id: 'Square', width: 1080, height: 1080},
  {id: 'Portrait', width: 1080, height: 1920},
];

export const Root: React.FC = () => (
  <Folder name="StandUpTimer">
    {FORMATS.map((f) => (
      <Composition key={f.id} id={f.id} component={Film} width={f.width} height={f.height} fps={T.fps} durationInFrames={T.duration} />
    ))}
  </Folder>
);
