import AppKit
import CoreGraphics
import Foundation

// 数据配置：由 05_过程文档/rebuild_dashboard.py 生成。
// 文件不存在时自动回退到内置演示数据，行为与初版完全一致。
struct Cfg {
    static let dict: [String: Any] = {
        let p = "04_传播与数据/dashboard_data.json"
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: p)),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else {
            return [:]
        }
        return j
    }()
    static func str(_ k: String, _ fallback: String) -> String {
        return (dict[k] as? String) ?? fallback
    }
    static func num(_ v: Any?) -> CGFloat {
        if let n = v as? NSNumber { return CGFloat(n.doubleValue) }
        if let s = v as? String { return CGFloat(Double(s) ?? 0) }
        return 0
    }
    static func isDemo() -> Bool { return str("watermark", "DEMO DATA") == "DEMO DATA" }
}

let W: CGFloat = 1200
let H: CGFloat = 940
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

let blue = NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1)   // #2563EB
let lightBlue = NSColor(calibratedRed: 0.957, green: 0.969, blue: 1.0, alpha: 1) // #F4F7FF
let ink = NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1)        // #333333
let muted = NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.55, alpha: 1)
let bg = NSColor(calibratedRed: 0.965, green: 0.973, blue: 0.988, alpha: 1)
let white = NSColor.white
let line = NSColor(calibratedRed: 0.87, green: 0.89, blue: 0.94, alpha: 1)

func box(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat,
         _ fill: NSColor, _ radius: CGFloat = 10, _ stroke: NSColor? = nil) {
    let r = CGRect(x: x, y: H - top - h, width: w, height: h)
    let path = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(fill.cgColor)
    ctx.fillPath()
    if let s = stroke {
        ctx.addPath(path)
        ctx.setStrokeColor(s.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }
}

func txt(_ s: String, _ x: CGFloat, _ top: CGFloat, _ size: CGFloat,
         _ color: NSColor, _ bold: Bool = false) {
    let font = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    let l = CTLineCreateWithAttributedString(a)
    ctx.textPosition = CGPoint(x: x, y: H - top - size * 1.05)
    CTLineDraw(l, ctx)
}

// 背景
box(0, 0, W, H, bg, 0)

// 顶部标题条
box(0, 0, W, 86, blue, 0)
txt("C7 内容传播 · 数据追踪看板", 34, 24, 26, white, true)
txt(Cfg.str("subtitle", "演示数据 · 发布后 7 日快照 · 生成于 2026-11-21"), 34, 56, 14,
    NSColor(calibratedRed: 0.85, green: 0.91, blue: 1.0, alpha: 1))
txt(Cfg.str("watermark", "DEMO DATA"), W - 160, 34, 16, white, true)

// KPI 卡片
var kpis: [(String, String)] = [
    ("总阅读量", "2,340"),
    ("总互动量", "318"),
    ("新增关注", "126"),
    ("平均完读率", "68%")
]
if let kc = Cfg.dict["kpis"] as? [[String: String]], !kc.isEmpty {
    kpis = kc.compactMap { d in
        guard let l = d["label"], let v = d["value"] else { return nil }
        return (l, v)
    }
}
let cw: CGFloat = 268
let gap: CGFloat = 22
for (i, k) in kpis.enumerated() {
    let x = 34 + CGFloat(i) * (cw + gap)
    box(x, 108, cw, 116, white, 12, line)
    txt(k.0, x + 20, 128, 15, muted)
    txt(k.1, x + 20, 156, 36, blue, true)
}
txt(Cfg.isDemo() ? "▲ 三篇累计 · 较首篇 +206%" : "▲ 三篇累计 · 逐篇趋势见下图", 34, 238, 13, blue, true)

// 柱状图区
box(34, 266, 1132, 286, white, 12, line)
txt("三篇文章阅读量趋势（24h vs 7 日）", 56, 286, 17, ink, true)
txt("第二篇起加入群内转发引导，第三篇叠加知乎分流", 56, 312, 13, muted)

let chartBase: CGFloat = 512
let chartLeft: CGFloat = 96
var data: [(String, CGFloat, CGFloat)] = [
    ("第1篇 翻译", 320, 540),
    ("第2篇 技能", 480, 820),
    ("第3篇 WebApp", 610, 980)
]
if let sc = Cfg.dict["series"] as? [[String: Any]], !sc.isEmpty {
    data = sc.map { s in
        (s["name"] as? String ?? "", Cfg.num(s["h24"]), Cfg.num(s["d7"]))
    }
}
let peak = data.map { max($0.1, $0.2) }.max() ?? 1000
let maxV: CGFloat = Cfg.isDemo() ? 1000 : max(1000, (peak * 1.15 / 250).rounded(.up) * 250)
let chartH: CGFloat = 160
// 网格线
for i in 0...4 {
    let v = maxV / 4 * CGFloat(i)
    let y = chartBase - v / maxV * chartH
    ctx.move(to: CGPoint(x: chartLeft, y: H - y))
    ctx.addLine(to: CGPoint(x: 1130, y: H - y))
    ctx.setStrokeColor(line.cgColor)
    ctx.setLineWidth(1)
    ctx.strokePath()
    txt("\(Int(v))", 50, y - 14, 12, muted)
}
let groupW: CGFloat = 260
for (i, d) in data.enumerated() {
    let gx = chartLeft + 40 + CGFloat(i) * groupW
    let h1 = d.1 / maxV * chartH
    let h2 = d.2 / maxV * chartH
    box(gx, chartBase - h1, 52, h1, lightBlue, 5, blue)
    box(gx + 60, chartBase - h2, 52, h2, blue, 5)
    txt("\(Int(d.1))", gx - 2, chartBase - h1 - 22, 13, muted)
    txt("\(Int(d.2))", gx + 58, chartBase - h2 - 22, 13, blue, true)
    txt(d.0, gx - 8, chartBase + 12, 13, ink)
}
// 图例
box(880, 286, 16, 16, lightBlue, 3, blue)
txt("24 小时", 904, 286, 13, muted)
box(990, 286, 16, 16, blue, 3)
txt("7 日", 1014, 286, 13, muted)

// 明细表
box(34, 570, 1132, 258, white, 12, line)
txt("逐篇明细与渠道来源", 56, 590, 17, ink, true)

let cols: [(String, CGFloat)] = [
    ("文章", 56), ("7日阅读", 300), ("点赞", 420), ("在看", 510),
    ("评论", 600), ("转发", 690), ("收藏", 780), ("新增关注", 880), ("主要渠道", 1000)
]
for c in cols { txt(c.0, c.1, 624, 13, muted, true) }

var rows: [[String]] = [
    ["第1篇 翻译", "540", "18", "9", "5", "7", "11", "22", "公众号 82%"],
    ["第2篇 技能", "820", "32", "15", "9", "14", "20", "43", "公众号 71%"],
    ["第3篇 WebApp", "980", "58", "26", "18", "27", "49", "61", "公众号 64%"]
]
if let rr = Cfg.dict["rows"] as? [[String]], !rr.isEmpty { rows = rr }
for (i, r) in rows.enumerated() {
    let y = 656 + CGFloat(i) * 46
    if i % 2 == 0 { box(50, y - 8, 1100, 42, lightBlue, 6) }
    for (j, v) in r.enumerated() { txt(v, cols[j].1, y, 14, ink, j == 0) }
}

// 页脚说明（长文本自动折行，避免真实数据说明溢出画布）
let noteText = Cfg.str("note", "说明：以上为演示用示例数据，用于展示追踪口径与趋势呈现方式；正式提交前请替换为公众号/知乎后台真实截图。")
let noteChars = Array(noteText)
if noteChars.count > 58 {
    txt(String(noteChars.prefix(58)), 34, 848, 12, muted)
    txt(String(noteChars.dropFirst(58).prefix(58)), 34, 870, 12, muted)
    txt("追踪口径：24h = 发布后 24 小时；7 日 = 发布后第 7 天；互动 = 点赞+在看+评论+转发+收藏", 34, 892, 12, muted)
} else {
    txt(noteText, 34, 858, 13, muted)
    txt("追踪口径：24h = 发布后 24 小时；7 日 = 发布后第 7 天；互动 = 点赞+在看+评论+转发+收藏", 34, 882, 13, muted)
}

guard let img = ctx.makeImage() else { exit(2) }
let url = URL(fileURLWithPath: "04_传播与数据/赵心皓_C7_数据截图_7日快照.png")
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { exit(3) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("OK dashboard [\(Cfg.str("watermark", "DEMO DATA"))]")
