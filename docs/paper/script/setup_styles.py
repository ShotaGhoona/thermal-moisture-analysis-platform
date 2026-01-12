#!/usr/bin/env python3
"""
reference.docx のスタイル設定スクリプト

使い方:
    python setup_styles.py

スタイル設定を変更したい場合は STYLE_CONFIG を編集してください
"""

from docx import Document
from docx.shared import Pt, Cm
from docx.enum.style import WD_STYLE_TYPE
from pathlib import Path

# =============================================================================
# スタイル設定（シンプル版）
# =============================================================================

STYLE_CONFIG = {
    # 本文（標準）
    "Normal": {
        "font_name": "MS 明朝",
        "font_size": Pt(10.5),
        "line_spacing": 1.15,
    },
    # 見出し1（章）
    "Heading 1": {
        "font_name": "MS ゴシック",
        "font_size": Pt(12),
        "bold": True,
        "space_before": Pt(6),
        "space_after": Pt(3),
    },
    # 見出し2（節）
    "Heading 2": {
        "font_name": "MS ゴシック",
        "font_size": Pt(11),
        "bold": True,
        "space_before": Pt(6),
        "space_after": Pt(2),
    },
    # 見出し3（項）
    "Heading 3": {
        "font_name": "MS ゴシック",
        "font_size": Pt(10.5),
        "bold": True,
        "space_before": Pt(8),
        "space_after": Pt(2),
    },
    # 見出し4
    "Heading 4": {
        "font_name": "MS ゴシック",
        "font_size": Pt(10.5),
        "bold": True,
        "space_before": Pt(6),
        "space_after": Pt(2),
    },
}

# =============================================================================

def setup_styles(doc_path: Path):
    """reference.docx のスタイルを設定"""
    doc = Document(doc_path)

    for style_name, config in STYLE_CONFIG.items():
        try:
            style = doc.styles[style_name]
        except KeyError:
            print(f"Warning: スタイル '{style_name}' が見つかりません")
            continue

        # フォント設定
        font = style.font
        if "font_name" in config:
            font.name = config["font_name"]
            font._element.rPr.rFonts.set(
                "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}eastAsia",
                config["font_name"]
            )
        if "font_size" in config:
            font.size = config["font_size"]
        if "bold" in config:
            font.bold = config["bold"]

        # 段落設定
        paragraph_format = style.paragraph_format
        if "space_before" in config:
            paragraph_format.space_before = config["space_before"]
        if "space_after" in config:
            paragraph_format.space_after = config["space_after"]
        if "line_spacing" in config:
            paragraph_format.line_spacing = config["line_spacing"]
        if "first_line_indent" in config:
            paragraph_format.first_line_indent = config["first_line_indent"]

        print(f"設定完了: {style_name}")

    doc.save(doc_path)
    print(f"\n保存完了: {doc_path}")


if __name__ == "__main__":
    script_dir = Path(__file__).parent
    reference_path = script_dir / "reference.docx"

    if not reference_path.exists():
        print(f"Error: {reference_path} が見つかりません")
        exit(1)

    setup_styles(reference_path)
