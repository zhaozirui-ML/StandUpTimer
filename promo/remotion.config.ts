import {Config} from '@remotion/cli/config';

// 帧先存成高质量 JPEG 再编码，比 PNG 快很多，画质肉眼无差
Config.setVideoImageFormat('jpeg');
Config.setJpegQuality(94);
Config.setCodec('h264');
// CRF 越小画质越高；16 适合作品集展示，渐变不容易出色带
Config.setCrf(16);
Config.setPixelFormat('yuv420p');
Config.setOverwriteOutput(true);
