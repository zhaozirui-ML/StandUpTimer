import {useVideoConfig} from 'remotion';

export type Format = 'landscape' | 'square' | 'portrait';
export type Layout = {width: number; height: number; fps: number; format: Format};
export type Rect = {x: number; y: number; w: number; h: number};
export type Point = {x: number; y: number};

// 三种比例共用一套动画，只在这里切换构图；三者短边都是 1080，所以字号可以通用
export const useLayout = (): Layout => {
  const {width, height, fps} = useVideoConfig();
  const ratio = width / height;
  const format: Format = ratio > 1.2 ? 'landscape' : ratio < 0.8 ? 'portrait' : 'square';
  return {width, height, fps, format};
};

export const pick = <T,>(layout: Layout, values: Record<Format, T>): T => values[layout.format];

// 桌面 mock 在画面里的位置（16:10 屏幕）
export const screenRect = (layout: Layout): Rect =>
  pick(layout, {
    landscape: {x: 660, y: 190, w: 1120, h: 700},
    square: {x: 80, y: 409, w: 920, h: 575},
    portrait: {x: 60, y: 800, w: 960, h: 600},
  });

export const menuBarH = (screenW: number) => screenW * 0.034;

// 菜单栏里 App 图标中心所在的横向比例
export const STATUS_GLYPH_X = 0.742;

export const statusPoint = (layout: Layout): Point => {
  const s = screenRect(layout);
  return {x: s.x + s.w * STATUS_GLYPH_X, y: s.y + menuBarH(s.w) / 2};
};

export const statusGlyphSize = (layout: Layout) => menuBarH(screenRect(layout).w) * 1.5;
