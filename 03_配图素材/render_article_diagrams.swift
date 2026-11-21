import AppKit
import CoreGraphics

// 通用绘图辅助（CoreGraphics 直接绘制，避免依赖 NSGraphicsContext）
var CH: CGFloat = 900
func render(filename: String, width W: CGFloat, height H: CGFloat,
            draw: (CGContext) -> Void) {
    CH = H
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
    draw(ctx)
    guard let img = ctx.makeImage() else { exit(2) }
    let url = URL(fileURLWithPath: "03_配图素材/" + filename)
    guard let d = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { exit(3) }
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
    print("OK \(filename)")
}

let blue = NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1)
let soft = NSColor(calibratedRed: 0.957, green: 0.969, blue: 1.0, alpha: 1)
let ink = NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1)
let muted = NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.55, alpha: 1)
let bg = NSColor.white
let line = NSColor(calibratedRed: 0.87, green: 0.89, blue: 0.94, alpha: 1)
let orange = NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.20, alpha: 1)

func box(_ ctx: CGContext, _ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat,
         _ fill: NSColor, _ radius: CGFloat = 10, _ stroke: NSColor? = nil) {
    let r = CGRect(x: x, y: CH - top - h, width: w, height: h)
    let path = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    if let s = stroke { ctx.addPath(path); ctx.setStrokeColor(s.cgColor); ctx.setLineWidth(1.5); ctx.strokePath() }
}

func txt(_ ctx: CGContext, _ s: String, _ x: CGFloat, _ top: CGFloat, _ size: CGFloat,
         _ color: NSColor, _ bold: Bool = false) {
    let font = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    let l = CTLineCreateWithAttributedString(a)
    ctx.textPosition = CGPoint(x: x, y: CH - top - size * 1.05)
    CTLineDraw(l, ctx)
}

func arrow(_ ctx: CGContext, _ x1: CGFloat, _ y: CGFloat, _ x2: CGFloat) {
    ctx.move(to: CGPoint(x: x1, y: CH - y)); ctx.addLine(to: CGPoint(x: x2, y: CH - y))
    ctx.setStrokeColor(blue.cgColor); ctx.setLineWidth(2); ctx.strokePath()
    ctx.move(to: CGPoint(x: x2, y: CH - y))
    ctx.addLine(to: CGPoint(x: x2 - 10, y: CH - y + 6))
    ctx.addLine(to: CGPoint(x: x2 - 10, y: CH - y - 6))
    ctx.closePath(); ctx.setFillColor(blue.cgColor); ctx.fillPath()
}

// 图 1：AI 翻译五步流水线
render(filename: "配图_文章1_五步流水线.png", width: 1200, height: 340) { c in
    box(c, 0, 0, 1200, 340, bg, 0)
    txt(c, "AI 翻译五步流水线", 40, 28, 22, ink, true)
    txt(c, "先建术语表，再翻正文 —— 顺序不能反", 40, 58, 14, muted)
    let steps = [("① 评估", "抽样 500 字\n判断价值"), ("② 抽取", "PDF→MD\n保住结构"),
                 ("③ 建术语表", "20-40 个\n核心术语"), ("④ AI 初翻", "800-1200 字\n结构化提示词"),
                 ("⑤ 三轮校对", "术语/逻辑\n通顺度")]
    let bw: CGFloat = 200
    for (i, s) in steps.enumerated() {
        let x = 40 + CGFloat(i) * 230
        box(c, x, 110, bw, 150, i == 2 ? soft : bg, 12, i == 2 ? blue : line)
        txt(c, s.0, x + 18, 132, 18, i == 2 ? blue : ink, true)
        let parts = s.1.split(separator: "\n")
        for (j, p) in parts.enumerated() { txt(c, String(p), x + 18, 170 + CGFloat(j) * 26, 14, muted) }
        if i < 4 { arrow(c, x + bw + 4, 185, x + bw + 24) }
    }
    box(c, 40, 280, 1120, 40, soft, 8)
    txt(c, "关键：术语一致性前置 + 格式保护 + 分段输入，比换更强的模型更有效", 58, 290, 14, blue, true)
}

// 图 2：AI 技能迭代循环
render(filename: "配图_文章2_技能迭代循环.png", width: 1200, height: 340) { c in
    box(c, 0, 0, 1200, 340, bg, 0)
    txt(c, "AI 技能从 0 到被 87 人使用的工作循环", 40, 28, 22, ink, true)
    txt(c, "一次只解决一个问题 · 每轮都亲自验收", 40, 58, 14, muted)
    let steps = [("01 做窄", "砍掉 80% 功能\n只留一个非它不可的理由"),
                 ("02 降门槛", "粘贴即用\n说明「不需要你做什么」"),
                 ("03 迭代", "4 版改动\n每版由真实失败驱动"),
                 ("04 小范围试", "先给 5 人用\n再公开发布")]
    let bw: CGFloat = 250
    for (i, s) in steps.enumerated() {
        let x = 40 + CGFloat(i) * 285
        box(c, x, 110, bw, 150, i == 3 ? soft : bg, 12, i == 3 ? blue : line)
        txt(c, s.0, x + 18, 132, 18, i == 3 ? blue : ink, true)
        let parts = s.1.split(separator: "\n")
        for (j, p) in parts.enumerated() { txt(c, String(p), x + 18, 170 + CGFloat(j) * 26, 14, muted) }
        if i < 3 { arrow(c, x + bw + 4, 185, x + bw + 28) }
    }
    box(c, 40, 280, 1120, 40, soft, 8)
    txt(c, "核心公式：技能价值 = 被使用次数 × 单次节省时间", 58, 290, 14, blue, true)
}

// 图 3：Web App 14 天路径
render(filename: "配图_文章3_14天路径.png", width: 1200, height: 340) { c in
    box(c, 0, 0, 1200, 340, bg, 0)
    txt(c, "代码小白的 14 天上线路径", 40, 28, 22, ink, true)
    txt(c, " handwriting 0 行 · AI 对话约 60 轮 · 部署占 4 天", 40, 58, 14, muted)
    let steps = [("Day 1-2", "需求砍到一个功能"), ("Day 3-6", "让 AI 选最简技术栈"),
                 ("Day 7-10", "一次一个功能\n每轮亲自验收"), ("Day 11-14", "部署 + 手机端验证")]
    let bw: CGFloat = 250
    for (i, s) in steps.enumerated() {
        let x = 40 + CGFloat(i) * 285
        box(c, x, 110, bw, 150, i == 3 ? soft : bg, 12, i == 3 ? blue : line)
        txt(c, s.0, x + 18, 132, 18, i == 3 ? blue : ink, true)
        let parts = s.1.split(separator: "\n")
        for (j, p) in parts.enumerated() { txt(c, String(p), x + 18, 172 + CGFloat(j) * 26, 14, muted) }
        if i < 3 { arrow(c, x + bw + 4, 185, x + bw + 28) }
    }
    box(c, 40, 280, 1120, 40, soft, 8)
    txt(c, "最贵的不是写代码，是「想清楚要什么」和「看出它对不对」", 58, 290, 14, blue, true)
}
