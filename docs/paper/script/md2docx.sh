#!/bin/bash

# =============================================================================
# splits/*.md → MMDD.docx 変換スクリプト
# =============================================================================
# 使い方:
#   ./md2docx.sh          # splits/内のmdをまとめて今日の日付.docxに変換
#   ./md2docx.sh 0115     # 出力ファイル名を指定（0115.docx）
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAPER_DIR="$(dirname "$SCRIPT_DIR")"
SPLITS_DIR="${PAPER_DIR}/splits"
REFERENCE_DOCX="${SCRIPT_DIR}/reference.docx"

# 出力ファイル名
if [ -n "$1" ]; then
    OUTPUT_NAME="$1"
else
    OUTPUT_NAME="$(date +%m%d)"
fi
OUTPUT_DOCX="${PAPER_DIR}/${OUTPUT_NAME}.docx"

# Pandocチェック
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc がインストールされていません"
    echo "インストール: brew install pandoc"
    exit 1
fi

# mdファイルを番号順に取得
MD_FILES=($(ls "$SPLITS_DIR"/*.md 2>/dev/null | sort))

if [ ${#MD_FILES[@]} -eq 0 ]; then
    echo "Error: splits/ 内に .md ファイルがありません"
    exit 1
fi

echo "=== DOCX 変換 ==="
echo "入力: ${#MD_FILES[@]} ファイル"
echo "出力: $OUTPUT_DOCX"

# 変換実行
pandoc "${MD_FILES[@]}" \
    -o "$OUTPUT_DOCX" \
    --from markdown \
    --to docx \
    --reference-doc="$REFERENCE_DOCX" \
    --number-sections

if [ $? -eq 0 ]; then
    echo "完了: $OUTPUT_DOCX"
else
    echo "Error: 変換に失敗しました"
    exit 1
fi
