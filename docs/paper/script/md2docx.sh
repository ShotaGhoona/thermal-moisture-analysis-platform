#!/bin/bash

# =============================================================================
# Markdown → Word / PDF 変換スクリプト
# =============================================================================
# 使い方:
#   ./md2docx.sh [入力.md] [出力.docx] [オプション]
#
# オプション:
#   -p, --pdf     PDFも生成する（出力.docx と同じ場所に .pdf を生成）
#   --pdf-only    PDFのみ生成する
#
# スタイル管理:
#   - reference.docx (同ディレクトリ) をテンプレートとして使用
#   - スタイル変更時は reference.docx をWordで開いて編集
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAPER_DIR="$(dirname "$SCRIPT_DIR")"

# デフォルト設定
INPUT_MD="${PAPER_DIR}/1202.md"
OUTPUT_DOCX="${PAPER_DIR}/output.docx"
REFERENCE_DOCX="${SCRIPT_DIR}/reference.docx"
GENERATE_PDF=false
PDF_ONLY=false

# Pandoc DOCX オプション
PANDOC_DOCX_OPTS=(
    --from markdown
    --to docx
    --reference-doc="$REFERENCE_DOCX"
)

# PDF変換方法: "word" (Microsoft Word経由) または "libreoffice"
PDF_METHOD="word"

# =============================================================================

# 引数処理
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--pdf)
            GENERATE_PDF=true
            shift
            ;;
        --pdf-only)
            GENERATE_PDF=true
            PDF_ONLY=true
            shift
            ;;
        -h|--help)
            echo "使い方: $0 [入力.md] [出力.docx] [オプション]"
            echo ""
            echo "オプション:"
            echo "  -p, --pdf     DOCXに加えてPDFも生成"
            echo "  --pdf-only    PDFのみ生成（DOCXは生成しない）"
            echo "  -h, --help    このヘルプを表示"
            exit 0
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# 位置引数を復元
if [ ${#POSITIONAL_ARGS[@]} -ge 1 ]; then
    INPUT_MD="${POSITIONAL_ARGS[0]}"
fi
if [ ${#POSITIONAL_ARGS[@]} -ge 2 ]; then
    OUTPUT_DOCX="${POSITIONAL_ARGS[1]}"
fi

# 出力PDFパス（DOCXと同じ場所に生成）
OUTPUT_PDF="${OUTPUT_DOCX%.docx}.pdf"

# Pandocチェック
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc がインストールされていません"
    echo "インストール: brew install pandoc"
    exit 1
fi

# PDF生成時の依存チェック
if [ "$GENERATE_PDF" = true ]; then
    if [ "$PDF_METHOD" = "word" ]; then
        # docx2pdf (Microsoft Word経由) をチェック
        if ! command -v docx2pdf &> /dev/null; then
            echo "Error: docx2pdf がインストールされていません"
            echo "インストール: pip install docx2pdf"
            exit 1
        fi
        # Microsoft Word の存在確認
        if [ ! -d "/Applications/Microsoft Word.app" ]; then
            echo "Error: Microsoft Word がインストールされていません"
            exit 1
        fi
    elif [ "$PDF_METHOD" = "libreoffice" ]; then
        # LibreOffice のパスを探す（macOS）
        if [ -d "/Applications/LibreOffice.app" ]; then
            SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
        elif command -v soffice &> /dev/null; then
            SOFFICE="soffice"
        else
            echo "Error: LibreOffice がインストールされていません"
            echo "インストール: brew install --cask libreoffice"
            exit 1
        fi
    fi
fi

# 入力ファイル確認
if [ ! -f "$INPUT_MD" ]; then
    echo "Error: 入力ファイルが見つかりません: $INPUT_MD"
    exit 1
fi

# 参照テンプレート確認（DOCX生成時のみ）
if [ "$PDF_ONLY" = false ] && [ ! -f "$REFERENCE_DOCX" ]; then
    echo "Error: 参照テンプレートが見つかりません: $REFERENCE_DOCX"
    echo "script/reference.docx を作成してください"
    exit 1
fi

# =============================================================================
# DOCX 変換
# =============================================================================
if [ "$PDF_ONLY" = false ]; then
    echo "=== DOCX 変換 ==="
    echo "入力: $INPUT_MD"
    echo "出力: $OUTPUT_DOCX"
    echo "テンプレート: $REFERENCE_DOCX"
    echo ""

    pandoc "$INPUT_MD" -o "$OUTPUT_DOCX" "${PANDOC_DOCX_OPTS[@]}"

    if [ $? -eq 0 ]; then
        echo "DOCX 変換完了: $OUTPUT_DOCX"
    else
        echo "Error: DOCX 変換に失敗しました"
        exit 1
    fi
fi

# =============================================================================
# PDF 変換
# =============================================================================
if [ "$GENERATE_PDF" = true ]; then
    echo ""
    echo "=== PDF 変換 ==="

    # DOCXが存在することを確認（PDF_ONLYの場合は先に生成）
    if [ ! -f "$OUTPUT_DOCX" ]; then
        echo "DOCX を先に生成します..."
        pandoc "$INPUT_MD" -o "$OUTPUT_DOCX" "${PANDOC_DOCX_OPTS[@]}"
    fi

    if [ "$PDF_METHOD" = "word" ]; then
        echo "Microsoft Word で PDF に変換中..."
        docx2pdf "$OUTPUT_DOCX" "$OUTPUT_PDF"

        if [ $? -eq 0 ]; then
            echo "PDF 変換完了: $OUTPUT_PDF"
        else
            echo "Error: PDF 変換に失敗しました"
            exit 1
        fi
    elif [ "$PDF_METHOD" = "libreoffice" ]; then
        echo "LibreOffice で PDF に変換中..."
        OUTPUT_DIR="$(dirname "$OUTPUT_DOCX")"
        "$SOFFICE" --headless --convert-to pdf --outdir "$OUTPUT_DIR" "$OUTPUT_DOCX"

        if [ $? -eq 0 ]; then
            echo "PDF 変換完了: $OUTPUT_PDF"
        else
            echo "Error: PDF 変換に失敗しました"
            exit 1
        fi
    fi
fi

echo ""
echo "全ての変換が完了しました"
