#!/usr/bin/env python3
"""
シンプルな章分割スクリプト
見出し1（#）レベルでファイルを分割する
"""

import re
from pathlib import Path


def split_by_chapter(input_file: Path, output_dir: Path):
    """見出し1レベルでマークダウンを分割"""
    content = input_file.read_text(encoding='utf-8')
    lines = content.split('\n')

    # 見出し1のパターン
    h1_pattern = re.compile(r'^#\s+(.+)$')

    chapters = []
    current_chapter = None
    preamble_lines = []

    for line in lines:
        match = h1_pattern.match(line)

        if match:
            # 前の章があれば保存
            if current_chapter:
                chapters.append(current_chapter)

            title = match.group(1).strip()
            current_chapter = {
                'title': title,
                'lines': [line]
            }
        else:
            if current_chapter:
                current_chapter['lines'].append(line)
            else:
                preamble_lines.append(line)

    # 最後の章を追加
    if current_chapter:
        chapters.append(current_chapter)

    # 出力ディレクトリ作成
    output_dir.mkdir(parents=True, exist_ok=True)

    # プリアンブル（目次など）を保存
    if preamble_lines:
        preamble_content = '\n'.join(preamble_lines).strip()
        if preamble_content:
            preamble_path = output_dir / '0-目次.md'
            preamble_path.write_text(preamble_content, encoding='utf-8')
            print(f"[FILE] {preamble_path}")

    # 各章を保存
    for i, chapter in enumerate(chapters, 1):
        # ファイル名に使えない文字を置換
        safe_title = chapter['title']
        for char in ['/', '\\', ':', '*', '?', '"', '<', '>', '|', '[', ']']:
            safe_title = safe_title.replace(char, '_')

        filename = f"{i}-{safe_title}.md"
        filepath = output_dir / filename

        content = '\n'.join(chapter['lines']).strip()
        filepath.write_text(content, encoding='utf-8')
        print(f"[FILE] {filepath}")

    print(f"\n✅ 完了: {len(chapters)}個の章ファイルを作成しました")


if __name__ == '__main__':
    script_dir = Path(__file__).parent
    input_file = script_dir / '1202.md'
    output_dir = script_dir / 'splits'

    if not input_file.exists():
        # 親ディレクトリからも探す
        input_file = script_dir.parent / '1202.md'

    print(f"📄 入力: {input_file}")
    print(f"📁 出力: {output_dir}\n")

    split_by_chapter(input_file, output_dir)
