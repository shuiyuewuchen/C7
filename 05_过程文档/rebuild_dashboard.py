#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
C7 数据看板回填工作流
--------------------
读取 04_传播与数据/赵心皓_C7_数据追踪表.csv，生成 04_传播与数据/dashboard_data.json，
再由两个 Swift 脚本渲染 PNG。设计原则：**不编造数据**。

- CSV 三篇的「7日阅读」全部填好  -> 真实数据模式，图面水印变为 REAL DATA
- 任一为空                      -> 演示数据模式，图面保留 DEMO DATA 水印
- D1..D7（每日累计阅读）填了     -> 曲线用真实逐日值
- 未填但有 24h / 7日           -> 曲线按线性插值，并在图面标注「中间日为插值估算」
- 全空                          -> 内置演示序列

用法（在仓库根目录运行）：
    python3 05_过程文档/rebuild_dashboard.py
    swift 03_配图素材/render_data_dashboard.swift
    swift 03_配图素材/render_growth_curve.swift
"""

import csv
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "04_传播与数据" / "赵心皓_C7_数据追踪表.csv"
OUT_PATH = ROOT / "04_传播与数据" / "dashboard_data.json"

DEMO = {
    "isDemo": True,
    "watermark": "DEMO DATA",
    "subtitle": "演示数据 · 发布后 7 日快照 · 生成于 2026-11-21",
    "subtitleCurve": "演示数据 · 累计阅读量随发布时间的变化",
    "note": "说明：以上为演示用示例数据，用于展示追踪口径与趋势呈现方式；正式提交前请替换为公众号/知乎后台真实截图。",
    "noteCurve": "说明：以上为演示用示例数据，用于展示追踪口径与趋势呈现方式；正式提交前请替换为公众号/知乎后台真实数据。",
    "kpis": [
        {"label": "总阅读量", "value": "2,340"},
        {"label": "总互动量", "value": "318"},
        {"label": "新增关注", "value": "126"},
        {"label": "平均完读率", "value": "68%"},
    ],
    "series": [
        {"name": "第1篇 翻译", "h24": 320, "d7": 540,
         "daily": [320, 380, 430, 470, 500, 520, 540],
         "row": ["第1篇 翻译", "540", "18", "9", "5", "7", "11", "22", "公众号 82%"]},
        {"name": "第2篇 技能", "h24": 480, "d7": 820,
         "daily": [480, 580, 660, 720, 770, 800, 820],
         "row": ["第2篇 技能", "820", "32", "15", "9", "14", "20", "43", "公众号 71%"]},
        {"name": "第3篇 WebApp", "h24": 610, "d7": 980,
         "daily": [610, 740, 840, 900, 940, 965, 980],
         "row": ["第3篇 WebApp", "980", "58", "26", "18", "27", "49", "61", "公众号 64%"]},
    ],
}

ARTICLE_KEYS = ["第1篇", "第2篇", "第3篇"]
COL_KEYS = ["7日阅读", "点赞", "在看", "评论", "转发", "收藏", "新增关注"]


def to_int(v):
    try:
        return int(str(v).strip().replace(",", ""))
    except (ValueError, AttributeError):
        return None


def read_csv():
    if not CSV_PATH.exists():
        return {}
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    found = {}
    for r in rows:
        name = (r.get("文章") or "").strip()
        platform = (r.get("平台") or "").strip()
        if not name or name.startswith(("口径说明", "判断规则")):
            continue
        if platform and platform != "微信公众号":
            continue  # 主口径取公众号；知乎单独统计
        for k in ARTICLE_KEYS:
            if name.startswith(k):
                found.setdefault(k, []).append(r)
    return {k: v[0] for k, v in found.items() if v}


def build():
    data = read_csv()
    needed = [k for k in ARTICLE_KEYS if k not in data or to_int(data[k].get("7日阅读")) is None]
    if needed:
        mode = "demo"
    else:
        mode = "real"

    if mode == "demo":
        cfg = json.loads(json.dumps(DEMO, ensure_ascii=False))
        cfg["rows"] = [s["row"] for s in cfg["series"]]
        cfg["pending"] = needed
        return cfg, mode

    # ---- 真实数据模式 ----
    cfg = json.loads(json.dumps(DEMO, ensure_ascii=False))
    cfg["isDemo"] = False
    cfg["watermark"] = "REAL DATA"
    today = date.today().isoformat()
    cfg["subtitle"] = f"真实数据 · 来源：公众号后台 · 回填于 {today}"
    cfg["subtitleCurve"] = f"真实数据 · 累计阅读量随发布时间的变化 · 回填于 {today}"

    total_read = 0
    total_inter = 0
    total_follow = 0
    interpolated = False

    for i, key in enumerate(ARTICLE_KEYS):
        r = data[key]
        s = cfg["series"][i]
        d7 = to_int(r.get("7日阅读")) or 0
        h24 = to_int(r.get("24h阅读")) or 0
        vals = {c: (to_int(r.get(c)) or 0) for c in COL_KEYS if c != "7日阅读"}
        daily_cols = [to_int(r.get(f"D{d}")) for d in range(1, 8)]
        if all(v is not None and v > 0 for v in daily_cols):
            daily = [float(v) for v in daily_cols]
        else:
            interpolated = True
            # 线性插值：D1 = 24h，D7 = 7 日，中间均匀过渡
            daily = [round(h24 + (d7 - h24) * (d - 1) / 6, 1) for d in range(1, 8)]
            daily[-1] = float(d7)

        s["h24"] = h24
        s["d7"] = d7
        s["daily"] = daily
        channel = (r.get("主要渠道") or "公众号").strip() or "公众号"
        s["row"] = [
            s["name"], str(d7),
            str(vals.get("点赞", 0)), str(vals.get("在看", 0)),
            str(vals.get("评论", 0)), str(vals.get("转发", 0)),
            str(vals.get("收藏", 0)), str(vals.get("新增关注", 0)),
            channel,
        ]
        total_read += d7
        total_inter += sum(vals.values())
        total_follow += vals.get("新增关注", 0)

    inter_note = "；曲线中间日为线性插值估算（可在 CSV 的 D1..D7 列填真实逐日值）" if interpolated else ""
    cfg["note"] = f"说明：数据来源为公众号/知乎后台真实记录，回填于 {today}{inter_note}。"
    cfg["noteCurve"] = cfg["note"]
    cfg["rows"] = [s["row"] for s in cfg["series"]]
    # 第 4 项只显示能由 CSV 直接算出的指标，不写无来源的占位文字
    engage_rate = (total_inter / total_read * 100) if total_read else 0
    cfg["kpis"] = [
        {"label": "总阅读量", "value": f"{total_read:,}"},
        {"label": "总互动量", "value": f"{total_inter:,}"},
        {"label": "新增关注", "value": f"{total_follow:,}"},
        {"label": "有效互动率", "value": f"{engage_rate:.1f}%"},
    ]
    return cfg, mode


def main():
    cfg, mode = build()
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"已生成：{OUT_PATH.relative_to(ROOT)}")
    if mode == "demo":
        print("模式：演示数据（保留 DEMO DATA 水印）")
        print("原因：CSV 中以下文章的「7日阅读」尚未填写 -> " + "、".join(cfg["pending"]))
        print("提示：发布后把真实数字填入 赵心皓_C7_数据追踪表.csv，再运行本脚本即可切换为真实数据。")
    else:
        print("模式：真实数据（水印切换为 REAL DATA，DEMO 标注自动消失）")
        print(f"总阅读 {cfg['kpis'][0]['value']} ｜ 总互动 {cfg['kpis'][1]['value']} ｜ 新增关注 {cfg['kpis'][2]['value']}")
    print("\n下一步（在仓库根目录执行）：")
    print("  swift 03_配图素材/render_data_dashboard.swift")
    print("  swift 03_配图素材/render_growth_curve.swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
