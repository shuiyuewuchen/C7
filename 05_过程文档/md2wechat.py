#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
md2wechat.py —— C7 内容生产工作流中的「排版」环节工具

把 Markdown 文章转换为微信公众号兼容的 HTML：
- 全部样式内联（公众号编辑器会剥离 <style> 与外部 CSS）
- 正文 15px / 行高 1.75 / 段间距 18px（移动端阅读优化）
- 配色不超过 3 种：正文 #333333、主色 #2563EB、浅底 #F4F7FF
- 图片占位块统一圆角 8px
- 无 JS、无外链资源，可直接复制粘贴进公众号编辑器

用法：
    python3 md2wechat.py 输入.md 输出.html

设计意图：这是 C7 内容生产 workflow 的可复用组件（C4 联动），
换一篇文章只需换输入路径，无需重新调排版。
"""

import html
import re
import sys
from pathlib import Path

TEXT = "#333333"
PRIMARY = "#2563EB"
SOFT = "#F4F7FF"


def inline(text: str) -> str:
    """处理行内 markdown：加粗、行内代码、链接。"""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", lambda m: (
        f'<code style="padding:2px 5px;background:{SOFT};color:{PRIMARY};'
        f'border-radius:4px;font-size:14px;font-family:Menlo,Consolas,monospace;">'
        f'{m.group(1)}</code>'), out)
    out = re.sub(r"\*\*([^*]+)\*\*", lambda m: (
        f'<strong style="color:{PRIMARY};">{m.group(1)}</strong>'), out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2" style="color:#2563EB;">\1</a>', out)
    return out


def render_table(lines):
    rows = []
    for ln in lines:
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        rows.append(cells)
    if len(rows) < 2:
        return ""
    header, body = rows[0], rows[2:]
    th = "".join(
        f'<th style="padding:9px 10px;background:{PRIMARY};color:#FFFFFF;'
        f'font-size:14px;text-align:left;font-weight:600;">{inline(c)}</th>'
        for c in header)
    trs = []
    for i, row in enumerate(body):
        tds = "".join(
            f'<td style="padding:9px 10px;border-bottom:1px solid #E5E9F2;'
            f'font-size:14px;color:{TEXT};vertical-align:top;">{inline(c)}</td>'
            for c in row)
        trs.append(f'<tr style="background:{"#FFFFFF" if i % 2 == 0 else SOFT};">{tds}</tr>')
    return (
        '<section style="margin:20px 0;overflow-x:auto;">'
        '<table style="width:100%;border-collapse:collapse;border-radius:8px;overflow:hidden;">'
        f'<thead><tr>{th}</tr></thead><tbody>{"".join(trs)}</tbody></table></section>')


def convert(md: str) -> str:
    lines = md.splitlines()
    out = []
    i = 0
    n = len(lines)
    in_code = False
    code_buf = []
    table_buf = []

    def flush_table():
        if table_buf:
            out.append(render_table(table_buf))
            table_buf.clear()

    while i < n:
        ln = lines[i]
        stripped = ln.strip()

        # 代码块
        if stripped.startswith("```"):
            flush_table()
            if not in_code:
                in_code = True
                code_buf = []
            else:
                in_code = False
                code_html = "<br>".join(html.escape(c, quote=False) for c in code_buf)
                out.append(
                    f'<section style="margin:20px 0;padding:16px;background:{SOFT};'
                    f'border-left:4px solid {PRIMARY};border-radius:8px;">'
                    f'<pre style="margin:0;white-space:pre-wrap;word-break:break-word;'
                    f'font-size:13px;line-height:1.7;color:{TEXT};'
                    f'font-family:Menlo,Consolas,monospace;">{code_html}</pre></section>')
            i += 1
            continue
        if in_code:
            code_buf.append(ln)
            i += 1
            continue

        # 表格
        if stripped.startswith("|") and stripped.endswith("|"):
            table_buf.append(stripped)
            i += 1
            continue
        flush_table()

        # 空行
        if not stripped:
            i += 1
            continue

        # 分隔线
        if re.fullmatch(r"-{3,}", stripped):
            out.append(f'<hr style="border:none;border-top:1px solid #E5E9F2;margin:28px 0;">')
            i += 1
            continue

        # 多选题块（以 > 开头，含引用）
        if stripped.startswith(">"):
            quote = []
            while i < n and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip().lstrip(">").strip())
                i += 1
            qhtml = "<br>".join(inline(q) for q in quote if q)
            out.append(
                f'<blockquote style="margin:20px 0;padding:14px 16px;background:{SOFT};'
                f'border-left:4px solid {PRIMARY};border-radius:8px;font-size:14px;'
                f'line-height:1.8;color:{TEXT};">{qhtml}</blockquote>')
            continue

        # 标题
        m = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if m:
            level, title = len(m.group(1)), m.group(2)
            sizes = {1: 22, 2: 19, 3: 17, 4: 16}
            size = sizes[level]
            if level == 1:
                out.append(
                    f'<h1 style="margin:0 0 24px;font-size:{size}px;line-height:1.5;'
                    f'color:{TEXT};font-weight:700;">{inline(title)}</h1>')
            elif level == 2:
                out.append(
                    f'<h2 style="margin:34px 0 16px;padding-left:12px;border-left:4px solid {PRIMARY};'
                    f'font-size:{size}px;line-height:1.5;color:{PRIMARY};font-weight:700;">'
                    f'{inline(title)}</h2>')
            else:
                out.append(
                    f'<h{level} style="margin:26px 0 12px;font-size:{size}px;line-height:1.5;'
                    f'color:{TEXT};font-weight:700;">{inline(title)}</h{level}>')
            i += 1
            continue

        # 列表
        m = re.match(r"^(\d+)\.\s+(.*)$", stripped)
        if m:
            items = []
            while i < n:
                mm = re.match(r"^\s*(\d+)\.\s+(.*)$", lines[i])
                if not mm:
                    break
                items.append(mm.group(2))
                i += 1
            lis = "".join(
                f'<li style="margin:8px 0;font-size:15px;line-height:1.75;color:{TEXT};">'
                f'{inline(v)}</li>' for v in items)
            out.append(f'<ol style="margin:14px 0;padding-left:24px;">{lis}</ol>')
            continue
        if stripped.startswith("- "):
            items = []
            while i < n and lines[i].strip().startswith("- "):
                items.append(lines[i].strip()[2:])
                i += 1
            lis = "".join(
                f'<li style="margin:8px 0;font-size:15px;line-height:1.75;color:{TEXT};">'
                f'{inline(v)}</li>' for v in items)
            out.append(f'<ul style="margin:14px 0;padding-left:24px;">{lis}</ul>')
            continue

        # 图片占位块（🖼 开头）
        if stripped.startswith("🖼"):
            out.append(
                f'<section style="margin:20px 0;padding:34px 16px;text-align:center;'
                f'background:{SOFT};border-radius:8px;color:{PRIMARY};font-size:14px;">'
                f'{inline(stripped)}</section>')
            i += 1
            continue

        # 普通段落
        out.append(
            f'<p style="margin:0 0 18px;font-size:15px;line-height:1.75;'
            f'color:{TEXT};letter-spacing:0.2px;">{inline(stripped)}</p>')
        i += 1

    flush_table()
    body = "\n".join(out)
    return (
        '<section style="max-width:677px;margin:0 auto;padding:20px 16px;'
        'background:#FFFFFF;font-family:-apple-system,BlinkMacSystemFont,'
        "'PingFang SC','Helvetica Neue',Arial,sans-serif;\">"
        + body + "</section>")


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    md = src.read_text(encoding="utf-8")
    dst.write_text(convert(md), encoding="utf-8")
    print(f"OK: {dst.name} ({len(md)} chars -> {dst.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
