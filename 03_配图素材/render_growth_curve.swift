import AppKit
import CoreGraphics

let W: CGFloat = 1200, H: CGFloat = 700
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let blue = NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1)
let orange = NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.20, alpha: 1)
let teal = NSColor(calibratedRed: 0.12, green: 0.65, blue: 0.60, alpha: 1)
let ink = NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1)
let muted = NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.55, alpha: 1)
let lineCol = NSColor(calibratedRed: 0.87, green: 0.89, blue: 0.94, alpha: 1)

func box(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor, _ r: CGFloat = 10) {
    let p = CGPath(roundedRect: CGRect(x: x, y: H - top - h, width: w, height: h),
                   cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(p); ctx.setFillColor(c.cgColor); ctx.fillPath()
}
func txt(_ s: String, _ x: CGFloat, _ top: CGFloat, _ size: CGFloat, _ c: NSColor, _ bold: Bool = false) {
    let a = NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular), .foregroundColor: c])
    ctx.textPosition = CGPoint(x: x, y: H - top - size * 1.05)
    CTLineDraw(CTLineCreateWithAttributedString(a), ctx)
}

box(0, 0, W, H, NSColor(calibratedRed: 0.965, green: 0.973, blue: 0.988, alpha: 1), 0)
box(0, 0, W, 80, blue, 0)
txt("C7 内容传播 · 7 日传播曲线", 34, 20, 24, .white, true)
txt("演示数据 · 累计阅读量随发布时间的变化", 34, 50, 14,
    NSColor(calibratedRed: 0.85, green: 0.91, blue: 1.0, alpha: 1))
txt("DEMO DATA", W - 160, 30, 16, .white, true)

box(34, 100, 1132, 520, .white, 12)
txt("三篇累计阅读量（发布后 1–7 天）", 56, 120, 17, ink, true)
txt("斜率变化：第 2 篇起加入群内转发引导，第 3 篇叠加知乎分流与跨篇导流", 56, 146, 13, muted)

let left: CGFloat = 90, right: CGFloat = 1130
let baseY: CGFloat = 570, topY: CGFloat = 200
let maxV: CGFloat = 1000
for v in stride(from: 0, through: 1000, by: 200) {
    let y = baseY - CGFloat(v) / maxV * (baseY - topY)
    ctx.move(to: CGPoint(x: left, y: H - y)); ctx.addLine(to: CGPoint(x: right, y: H - y))
    ctx.setStrokeColor(lineCol.cgColor); ctx.setLineWidth(1); ctx.strokePath()
    txt("\(v)", 52, y - 14, 12, muted)
}
for d in 1...7 {
    let x = left + CGFloat(d - 1) / 6 * (right - left)
    txt("第\(d)天", x - 18, baseY + 12, 12, muted)
}

let series: [(String, [CGFloat], NSColor)] = [
    ("第1篇 翻译", [320, 380, 430, 470, 500, 520, 540], blue),
    ("第2篇 技能", [480, 580, 660, 720, 770, 800, 820], orange),
    ("第3篇 WebApp", [610, 740, 840, 900, 940, 965, 980], teal)
]
for s in series {
    var pts: [CGPoint] = []
    for (i, v) in s.1.enumerated() {
        let x = left + CGFloat(i) / 6 * (right - left)
        let y = baseY - v / maxV * (baseY - topY)
        pts.append(CGPoint(x: x, y: H - y))
    }
    ctx.move(to: pts[0])
    for p in pts.dropFirst() { ctx.addLine(to: p) }
    ctx.setStrokeColor(s.2.cgColor); ctx.setLineWidth(3); ctx.strokePath()
    for p in pts {
        ctx.addEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        ctx.setFillColor(s.2.cgColor); ctx.fillPath()
    }
    let last = pts[pts.count - 1]
    txt("\(Int(s.1.last!))", last.x - 44, H - last.y - 30, 14, s.2, true)
}

// 图例
for (i, s) in series.enumerated() {
    let x = 56 + CGFloat(i) * 240
    box(x, 166, 18, 12, s.2, 3)
    txt(s.0, x + 26, 164, 13, ink)
}
txt("说明：以上为演示用示例数据，用于展示追踪口径与趋势呈现方式；正式提交前请替换为公众号/知乎后台真实数据。", 34, 648, 13, muted)

guard let img = ctx.makeImage() else { exit(2) }
let url = URL(fileURLWithPath: "04_传播与数据/赵心皓_C7_数据截图_7日传播曲线.png")
let d = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
print("OK curve")
