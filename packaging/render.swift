// 用系统 WebKit(Safari 同款渲染引擎)把 SVG 渲染成透明背景的 PNG
// 用法:render-icon 输入.svg 输出.png 像素尺寸
// 一般不用手动调用,运行 `make icon` 会自动生成全部尺寸
//
// 为什么不用 qlmanage / sips:它们渲染 SVG 时会垫一层白色背景,
// 图标圆角外面会变成白色方角;这里关掉 WebKit 的背景色,输出才是透明的。
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 4, let size = Double(args[3]).map({ CGFloat($0) }) else {
    print("用法:render-icon 输入.svg 输出.png 像素尺寸")
    exit(1)
}
let svgURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

// 命令行程序默认没有 App 环境,WebKit 需要它才能工作;.prohibited 表示不在 Dock 里出现图标
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

final class Renderer: NSObject, WKNavigationDelegate {
    let web: WKWebView
    // 尺寸和输出路径通过 init 传进来保存;Swift 不允许类直接引用外层 guard let 定义的变量
    let size: CGFloat
    let outURL: URL

    init(size: CGFloat, outURL: URL) {
        self.size = size
        self.outURL = outURL
        // 视图按 SVG 原始画布 1024×1024 布局,截图时再缩放到目标尺寸(矢量缩放,不会糊)
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        web.setValue(false, forKey: "drawsBackground") // 关键:不画白色背景 → 透明
        super.init()
        web.navigationDelegate = self
    }

    // 页面加载完成后截图
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let cfg = WKSnapshotConfiguration()
        // snapshotWidth 的单位是"点"而不是像素:Retina 屏 1 点 = 2 像素,普通屏 1 点 = 1 像素
        // 所以要除以屏幕的缩放倍数,才能得到正好 size 像素宽的截图
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        cfg.snapshotWidth = NSNumber(value: Double(size / scale))

        // [self]:显式声明这段回调会用到 self 的 size / outURL(Swift 要求写明)
        webView.takeSnapshot(with: cfg) { [self] image, error in
            guard let image, let tiff = image.tiffRepresentation,
                  let snapshot = NSBitmapImageRep(data: tiff) else {
                print("渲染失败:", error?.localizedDescription ?? "未知错误")
                exit(1)
            }
            // 画到一张精确 size×size、带透明通道的画布上,保证输出尺寸分毫不差
            let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
            NSGraphicsContext.current?.imageInterpolation = .high
            snapshot.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()

            do {
                try output.representation(using: .png, properties: [:])!.write(to: outURL)
                exit(0)
            } catch {
                print("写入失败:", error.localizedDescription)
                exit(1)
            }
        }
    }
}

// 把 SVG 包进一个无边距、透明背景的 HTML 页面里再加载
let svg: String
do {
    svg = try String(contentsOf: svgURL, encoding: .utf8)
} catch {
    print("读取 SVG 失败:", error.localizedDescription)
    exit(1)
}
let html = "<html><body style='margin:0;background:transparent'><div style='width:1024px;height:1024px'>\(svg)</div></body></html>"
let renderer = Renderer(size: size, outURL: outURL)
renderer.web.loadHTMLString(html, baseURL: nil)
app.run() // 启动事件循环,等 WebKit 加载完成;截图结束后在回调里 exit
