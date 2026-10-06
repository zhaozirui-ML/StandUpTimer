import Foundation

/// 6 套休息画面，系列名「一天里的光」：休息开始时最暗最冷，随进度变亮变暖，光源从右下升起。
/// 明度分三档：明（晨雾、莫兰迪）、中深（睡莲）、深（日出、蓝调、林荫）。
/// 对比度验收（8 种屏幕比例 × 整个休息进度 × 色块漂移的极端位置）全部达标：
/// 主文字 ≥6.3:1，次文字 ≥4.93:1（晨雾副标题，余量最小），按钮描边 ≥3.56:1（莫兰迪）。
/// 暗色主题里暖色只出现在高明度的光源里，避免低明度暖色发脏（旧日出的酒红就是这个问题）。
extension BreakTheme {
    static func named(_ id: BreakThemeID) -> BreakTheme {
        switch id {
        case .mist: mist
        case .morandi: morandi
        case .waterLily: waterLily
        case .sunrise: sunrise
        case .blueHour: blueHour
        case .forest: forest
        }
    }

    /// 晨雾：清晨薄雾。色相取自图标：冷色 #4F5BFF 推到雾蓝，底板粉与 warm 推到珍珠粉和杏色。
    /// 雾团随进度变淡（blobFade），上半屏保持清冷，暖色只在下部和光源里
    static let mist = BreakTheme(
        id: .mist, name: "晨雾", appearance: .light,
        baseStart: [0xB3C9D8, 0xBCCFDD, 0xC7D3E0, 0xD1D4DF, 0xD7D3E0],
        baseEnd: [0xC5DBE9, 0xDBE4ED, 0xF1E2E2, 0xF8E5DD, 0xFEEAD9],
        blobs: [Blob(rgb: 0xA4B4BD, alpha: 0.22), Blob(rgb: 0xF7F4EF, alpha: 0.55), Blob(rgb: 0xECF1F4, alpha: 0.45)],
        blobFade: 0.4,
        halo: [Stop(rgb: 0xFFF6EC, alpha: 0.55), Stop(rgb: 0xFBEDE2, alpha: 0.3), Stop(rgb: 0xF7E3D8, alpha: 0.1), Stop(rgb: 0xF6E0D6, alpha: 0)],
        core: [Stop(rgb: 0xFFFAF2, alpha: 0.95), Stop(rgb: 0xFFF2E5, alpha: 0.82), Stop(rgb: 0xFDEADB, alpha: 0.4), Stop(rgb: 0xFBE6D4, alpha: 0)],
        textPrimary: 0x252F3A, textSecondary: 0x47515C,
        surface: 0xFFFFFF
    )

    /// 莫兰迪：午后静物台。取自 Giorgio Morandi 两幅静物的 OKLab 聚类（暖灰 h75–95），提亮后使用；
    /// 三个色块是灰粉碗、赭黄罐、灰绿瓶，80%–90% 之间的明度台阶是「桌沿」
    static let morandi = BreakTheme(
        id: .morandi, name: "莫兰迪", appearance: .light,
        baseStart: [0xDDD7CA, 0xD9D1C5, 0xD4CCBE, 0xC8BDAE, 0xC6B9A9],
        baseEnd: [0xEFE8DC, 0xEDE4D8, 0xEBE0D4, 0xE4D2C7, 0xE3CEC4],
        blobs: [Blob(rgb: 0xC9ADA4, alpha: 0.38), Blob(rgb: 0xD9C59C, alpha: 0.3), Blob(rgb: 0xA9B2A2, alpha: 0.34)],
        halo: [Stop(rgb: 0xFFF6E6, alpha: 0.7), Stop(rgb: 0xF7EAD4, alpha: 0.38), Stop(rgb: 0xF2DDC6, alpha: 0.12), Stop(rgb: 0xF0D9C4, alpha: 0)],
        core: [Stop(rgb: 0xFFFBF3, alpha: 0.95), Stop(rgb: 0xFFF6E8, alpha: 0.72), Stop(rgb: 0xFEEFDB, alpha: 0.36), Stop(rgb: 0xFCEBD6, alpha: 0)],
        textPrimary: 0x3E3935, textSecondary: 0x514B45,
        surface: 0xFFFFFF
    )

    /// 睡莲：满幅水面，没有地平线。取自莫奈《蓝色睡莲》和《睡莲·云》的 OKLab 聚类：
    /// 水面紫 #636C8C、柳影 #50686D、睡莲粉；光源是水面上的云影反光
    static let waterLily = BreakTheme(
        id: .waterLily, name: "睡莲", appearance: .dark,
        baseStart: [0x272B49, 0x25304A, 0x233544, 0x233741, 0x22393F],
        baseEnd: [0x363C60, 0x323F5B, 0x304556, 0x304854, 0x2F4A52],
        blobs: [Blob(rgb: 0x636C8C, alpha: 0.42), Blob(rgb: 0x50686D, alpha: 0.48), Blob(rgb: 0xE4C8D4, alpha: 0.12)],
        halo: [Stop(rgb: 0xDCCBE0, alpha: 0.4), Stop(rgb: 0xB4ABD6, alpha: 0.17), Stop(rgb: 0x8487B8, alpha: 0.05), Stop(rgb: 0x8487B8, alpha: 0)],
        core: [Stop(rgb: 0xF5F0E4, alpha: 0.85), Stop(rgb: 0xEDE2E6, alpha: 0.55), Stop(rgb: 0xD6CBE2, alpha: 0.15), Stop(rgb: 0xD6CBE2, alpha: 0)],
        textPrimary: 0xF4F1E6, textSecondary: 0xC9CCDE,
        surface: 0x272B49
    )

    /// 日出：靛蓝夜空，右下奶油色晨光升起。全部从图标推导：底色取冷色 #4F5BFF 的色相压暗，
    /// 色块是冷色原色、冷色到 rose 的 30% 插值、偏青 10° 的冷色；玫红和橙只以高明度出现在光源里
    static let sunrise = BreakTheme(
        id: .sunrise, name: "日出", appearance: .dark,
        baseStart: [0x0A0D23, 0x111337, 0x1A1847, 0x201A4D, 0x251B52],
        baseEnd: [0x111531, 0x26265B, 0x3B3472, 0x433879, 0x4B3D81],
        blobs: [Blob(rgb: 0x4F5BFF, alpha: 0.16), Blob(rgb: 0x8868DF, alpha: 0.14), Blob(rgb: 0x3D7BFF, alpha: 0.1)],
        halo: [Stop(rgb: 0xFFE6D2, alpha: 0.85), Stop(rgb: 0xD8BCF0, alpha: 0.38), Stop(rgb: 0x8A8CF5, alpha: 0.12), Stop(rgb: 0x8A8CF5, alpha: 0)],
        core: [Stop(rgb: 0xFFF9F0, alpha: 1), Stop(rgb: 0xFFE9D4, alpha: 0.95), Stop(rgb: 0xFFD0B4, alpha: 0.55), Stop(rgb: 0xFFD0B4, alpha: 0)],
        textPrimary: 0xFFF5EE, textSecondary: 0xCDCAF6,
        surface: 0x0A0D23
    )

    /// 蓝调：日出前的蓝调时刻，海平线一点点亮成浅青，反光从右下水里升起。全系列最冷静，没有暖色
    static let blueHour = BreakTheme(
        id: .blueHour, name: "蓝调", appearance: .dark,
        baseStart: [0x021121, 0x031B2C, 0x032838, 0x003140, 0x023C49],
        baseEnd: [0x0A1D36, 0x0B2E46, 0x10525F, 0x2F7680, 0x7FBEC1],
        blobs: [Blob(rgb: 0x7DB9DE, alpha: 0.07), Blob(rgb: 0x0D5661, alpha: 0.4), Blob(rgb: 0x08192D, alpha: 0.45)],
        halo: [Stop(rgb: 0xA5DEE4, alpha: 0.32), Stop(rgb: 0x7FC6C9, alpha: 0.15), Stop(rgb: 0x33A6B8, alpha: 0.03), Stop(rgb: 0x33A6B8, alpha: 0)],
        core: [Stop(rgb: 0xFFF8EC, alpha: 0.95), Stop(rgb: 0xEEF9F6, alpha: 0.8), Stop(rgb: 0xBDE7EA, alpha: 0.4), Stop(rgb: 0xA5DEE4, alpha: 0)],
        textPrimary: 0xF2F8F8, textSecondary: 0xA4C5C8,
        surface: 0x021121
    )

    /// 林荫：午后林荫深处，林地被低斜的阳光照亮，底部泛出白绿，右下透进一团蜂蜜色芯的光
    static let forest = BreakTheme(
        id: .forest, name: "林荫", appearance: .dark,
        baseStart: [0x011211, 0x011A16, 0x04231B, 0x09281E, 0x0F3023],
        baseEnd: [0x061E1D, 0x0C3029, 0x224F3C, 0x3A6F53, 0x72A780],
        blobs: [Blob(rgb: 0x0B1C19, alpha: 0.5), Blob(rgb: 0xA8D8B9, alpha: 0.08), Blob(rgb: 0x69B0AC, alpha: 0.14)],
        halo: [Stop(rgb: 0xCDEBC9, alpha: 0.28), Stop(rgb: 0xB2DDBD, alpha: 0.14), Stop(rgb: 0x86C2B0, alpha: 0.04), Stop(rgb: 0x69B0AC, alpha: 0)],
        core: [Stop(rgb: 0xFFF3D6, alpha: 1), Stop(rgb: 0xECF5D7, alpha: 0.9), Stop(rgb: 0xC4E6CC, alpha: 0.5), Stop(rgb: 0xA8D8B9, alpha: 0)],
        textPrimary: 0xF2F5EA, textSecondary: 0xABC5B6,
        surface: 0x011211
    )
}
