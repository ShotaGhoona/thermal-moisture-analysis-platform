#!/bin/bash

# =============================================================================
# Markdown → Word 変換スクリプト
# =============================================================================
# スタイル管理:
#   - reference.docx (同ディレクトリ) をテンプレートとして使用
#   - スタイル変更時は reference.docx をWordで開いて編集:
#     1. 「見出し1」「見出し2」等のスタイルを右クリック→変更
#     2. フォント、サイズ、段落設定を調整して保存
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAPER_DIR="$(dirname "$SCRIPT_DIR")"

# ファイルパス設定
INPUT_MD="${PAPER_DIR}/0112.md"
OUTPUT_DOCX="${PAPER_DIR}/output.docx"
REFERENCE_DOCX="${SCRIPT_DIR}/reference.docx"

# Pandoc オプション設定
PANDOC_OPTS=(
    --from markdown
    --to docx
    --reference-doc="$REFERENCE_DOCX"
    # --toc                    # 目次を自動生成する場合はコメント解除
    # --toc-depth=3            # 目次の深さ
    # --number-sections        # 見出しに番号を付ける場合
)

# =============================================================================

# 引数処理
if [ -n "$1" ]; then
    INPUT_MD="$1"
fi

if [ -n "$2" ]; then
    OUTPUT_DOCX="$2"
fi

# Pandocチェック
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc がインストールされていません"
    echo "インストール: brew install pandoc"
    exit 1
fi

# 入力ファイル確認
if [ ! -f "$INPUT_MD" ]; then
    echo "Error: 入力ファイルが見つかりません: $INPUT_MD"
    exit 1
fi

# 参照テンプレート確認
if [ ! -f "$REFERENCE_DOCX" ]; then
    echo "Error: 参照テンプレートが見つかりません: $REFERENCE_DOCX"
    echo "script/reference.docx を作成してください"
    exit 1
fi

# 変換実行
echo "入力: $INPUT_MD"
echo "出力: $OUTPUT_DOCX"
echo "テンプレート: $REFERENCE_DOCX"
echo ""

pandoc "$INPUT_MD" -o "$OUTPUT_DOCX" "${PANDOC_OPTS[@]}"

if [ $? -eq 0 ]; then
    echo "変換完了: $OUTPUT_DOCX"
else
    echo "Error: 変換に失敗しました"
    exit 1
fi
