// 品牌 token：全部取自 packaging/AppIcon.svg，保证视频和 App 图标是同一套语言
export const color = {
  // 图标底板
  paperTop: '#F8E3EA',
  paperBottom: '#EDC7D6',
  // 图标线条渐变：冷色 = 坐着，暖色 = 站起来
  cold: '#4F5BFF',
  rose: '#FF5C8A',
  warm: '#FFA24D',
  // 贴纸描边与投影
  sticker: '#FFFFFF',
  stickerShadow: '#B0567A',
  // 文字：带品牌色倾向的深色，不用纯黑
  ink: '#2A1433',
  inkSoft: '#7A5A78',
  // 「日出」遮罩
  night: '#140B24',
  dusk: '#3A1640',
  ember: '#E8567E',
  glow: '#FFC48A',
  cream: '#FFF4EC',
  moonlight: '#E4C3CF',
} as const;

export const font = {
  cjk: '"PingFang SC", sans-serif',
  rounded: '"SF Pro Rounded", "PingFang SC", sans-serif',
  text: '"SF Pro Text", "SF Pro Display", "PingFang SC", sans-serif',
} as const;
