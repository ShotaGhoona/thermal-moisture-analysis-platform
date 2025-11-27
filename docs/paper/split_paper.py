#!/usr/bin/env python3
"""
卒論マークダウン分割スクリプト

機能：
1. 単一のmdファイルを章節ごとにフォルダ・ファイルに分割
2. 分割されたファイルを単一のmdファイルに結合（逆変換）

使用例：
    # 分割（1127.md → 01/フォルダ構造）
    python split_paper.py split 1127.md 01

    # 結合（01/フォルダ構造 → output.md）
    python split_paper.py merge 01 output.md

    # ドライラン（実行せずに構造確認）
    python split_paper.py split 1127.md 01 --dry-run
"""

import argparse
import re
import os
from pathlib import Path
from datetime import datetime


def sanitize_name(name: str) -> str:
    """ファイル名/フォルダ名に使えない文字を置換"""
    # 全角・半角の問題ある文字を置換
    invalid_chars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|', '[', ']']
    result = name.strip()
    for char in invalid_chars:
        result = result.replace(char, '_')
    return result


def parse_markdown_structure(content: str) -> list:
    """
    マークダウンを解析して構造化データを返す

    Returns:
        list of dict: [
            {
                'level': 1,  # 見出しレベル
                'title': '序論',
                'content': '...',  # この見出しに属する本文（次の同レベル以上の見出しまで）
                'line_number': 189
            },
            ...
        ]
    """
    lines = content.split('\n')
    sections = []
    current_section = None
    header_pattern = re.compile(r'^(#{1,6})\s+(.+)$')

    # 目次部分（最初の#見出しより前）を保存
    preamble_lines = []
    found_first_header = False

    for i, line in enumerate(lines, 1):
        match = header_pattern.match(line)

        if match:
            found_first_header = True
            level = len(match.group(1))
            title = match.group(2).strip()

            # 前のセクションがあれば保存
            if current_section:
                sections.append(current_section)

            current_section = {
                'level': level,
                'title': title,
                'content_lines': [],
                'line_number': i
            }
        else:
            if not found_first_header:
                preamble_lines.append(line)
            elif current_section:
                current_section['content_lines'].append(line)

    # 最後のセクションを追加
    if current_section:
        sections.append(current_section)

    # content_lines を content に変換
    for section in sections:
        section['content'] = '\n'.join(section['content_lines']).strip()
        del section['content_lines']

    return {
        'preamble': '\n'.join(preamble_lines).strip(),
        'sections': sections
    }


def build_folder_structure(parsed_data: dict, version_prefix: str = "v1") -> dict:
    """
    解析データからフォルダ・ファイル構造を構築

    フォルダ番号体系:
    - 見出し1 (# ): 100, 200, 300, ...
    - 見出し2 (## ): 110, 120, 130, ... (親+10, +20, ...)
    - 見出し3 (###): ファイルとして保存（番号なし）
    """
    sections = parsed_data['sections']
    structure = {
        'preamble': parsed_data['preamble'],
        'folders': [],
        'files': []  # 直下に置くファイル
    }

    # 見出し1のカウンター
    h1_counter = 0
    h2_counter = 0

    current_h1 = None
    current_h2 = None

    for section in sections:
        level = section['level']
        title = sanitize_name(section['title'])

        if level == 1:
            h1_counter += 1
            h2_counter = 0

            folder_num = h1_counter * 100
            folder_name = f"{folder_num}-{title}"

            current_h1 = {
                'name': folder_name,
                'number': folder_num,
                'subfolders': [],
                'files': [],
                'title': section['title'],
                'content': section['content']
            }
            structure['folders'].append(current_h1)
            current_h2 = None

        elif level == 2:
            h2_counter += 1

            if current_h1:
                folder_num = current_h1['number'] + h2_counter * 10
                folder_name = f"{folder_num}-{title}"

                current_h2 = {
                    'name': folder_name,
                    'number': folder_num,
                    'files': [],
                    'title': section['title'],
                    'content': section['content']
                }
                current_h1['subfolders'].append(current_h2)
            else:
                # h1がない場合はトップレベルに
                h1_counter += 1
                folder_num = h1_counter * 100 + h2_counter * 10
                folder_name = f"{folder_num}-{title}"

                current_h2 = {
                    'name': folder_name,
                    'number': folder_num,
                    'files': [],
                    'title': section['title'],
                    'content': section['content']
                }
                structure['folders'].append(current_h2)

        elif level == 3:
            # ファイル名: v1-タイトル.md （番号なし）
            file_name = f"{version_prefix}-{title}.md"

            if current_h2:
                current_h2['files'].append({
                    'name': file_name,
                    'title': section['title'],
                    'content': section['content']
                })
            elif current_h1:
                current_h1['files'].append({
                    'name': file_name,
                    'title': section['title'],
                    'content': section['content']
                })

        elif level >= 4:
            # 見出し4以降は見出し3のコンテンツに含める
            # TODO: 必要に応じて拡張
            pass

    return structure


def create_file_content(title: str, content: str, level: int = 3) -> str:
    """マークダウンファイルの内容を生成"""
    header_prefix = '#' * level
    if content:
        return f"{header_prefix} {title}\n\n{content}\n"
    else:
        return f"{header_prefix} {title}\n"


def write_structure_to_disk(structure: dict, output_dir: Path, version_prefix: str, dry_run: bool = False):
    """
    構造をディスクに書き出す
    """
    created_items = []

    # プリアンブル（目次など）を保存
    if structure['preamble']:
        preamble_path = output_dir / f"{version_prefix}-preamble.md"
        created_items.append(('file', preamble_path, structure['preamble']))

    for h1_folder in structure['folders']:
        h1_path = output_dir / h1_folder['name']
        created_items.append(('dir', h1_path, None))

        # h1直下のファイル（h3がh2なしで来た場合）
        for file_info in h1_folder.get('files', []):
            file_path = h1_path / file_info['name']
            content = create_file_content(file_info['title'], file_info['content'], level=3)
            created_items.append(('file', file_path, content))

        # h2サブフォルダ
        for h2_folder in h1_folder.get('subfolders', []):
            h2_path = h1_path / h2_folder['name']
            created_items.append(('dir', h2_path, None))

            # h2の本文ファイル（内容が空でも作成）
            h2_title = sanitize_name(h2_folder['title'])
            h2_content_path = h2_path / f"{version_prefix}-{h2_title}.md"
            content = create_file_content(h2_folder['title'], h2_folder.get('content', ''), level=2)
            created_items.append(('file', h2_content_path, content))

            # h3ファイル
            for file_info in h2_folder.get('files', []):
                file_path = h2_path / file_info['name']
                content = create_file_content(file_info['title'], file_info['content'], level=3)
                created_items.append(('file', file_path, content))

    # 実行
    if dry_run:
        print("\n=== ドライラン: 以下の構造が作成されます ===\n")
        for item_type, path, content in created_items:
            if item_type == 'dir':
                print(f"[DIR]  {path}")
            else:
                preview = content[:50].replace('\n', ' ') if content else ''
                print(f"[FILE] {path}")
                if preview:
                    print(f"       → {preview}...")
        print(f"\n合計: ディレクトリ {sum(1 for x in created_items if x[0] == 'dir')}個, "
              f"ファイル {sum(1 for x in created_items if x[0] == 'file')}個")
    else:
        output_dir.mkdir(parents=True, exist_ok=True)

        for item_type, path, content in created_items:
            if item_type == 'dir':
                path.mkdir(parents=True, exist_ok=True)
                print(f"[DIR]  {path}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding='utf-8')
                print(f"[FILE] {path}")

        print(f"\n✅ 完了: {output_dir}")


def merge_structure_to_file(input_dir: Path, output_file: Path, dry_run: bool = False):
    """
    フォルダ構造から単一のmdファイルに結合
    """
    all_content = []

    # プリアンブルを探す
    preamble_files = list(input_dir.glob("*-preamble.md"))
    if preamble_files:
        preamble_files.sort()
        for pf in preamble_files:
            content = pf.read_text(encoding='utf-8').strip()
            if content:
                all_content.append(content)

    # h1フォルダを数値順にソート
    h1_folders = sorted(
        [d for d in input_dir.iterdir() if d.is_dir()],
        key=lambda x: int(re.match(r'^(\d+)', x.name).group(1)) if re.match(r'^(\d+)', x.name) else 999
    )

    for h1_folder in h1_folders:
        # h1のoverviewファイル
        h1_files = sorted(h1_folder.glob("*-overview.md"))
        for f in h1_files:
            all_content.append(f.read_text(encoding='utf-8').strip())

        # h2サブフォルダを数値順にソート
        h2_folders = sorted(
            [d for d in h1_folder.iterdir() if d.is_dir()],
            key=lambda x: int(re.match(r'^(\d+)', x.name).group(1)) if re.match(r'^(\d+)', x.name) else 999
        )

        for h2_folder in h2_folders:
            # h2のoverviewファイル
            h2_files = sorted(h2_folder.glob("*-overview.md"))
            for f in h2_files:
                all_content.append(f.read_text(encoding='utf-8').strip())

            # h3ファイル（overview以外）
            h3_files = sorted([
                f for f in h2_folder.glob("*.md")
                if 'overview' not in f.name
            ])
            for f in h3_files:
                all_content.append(f.read_text(encoding='utf-8').strip())

        # h1直下のファイル（overview以外）
        h1_direct_files = sorted([
            f for f in h1_folder.glob("*.md")
            if 'overview' not in f.name
        ])
        for f in h1_direct_files:
            all_content.append(f.read_text(encoding='utf-8').strip())

    final_content = '\n\n'.join(all_content)

    if dry_run:
        print("\n=== ドライラン: 以下の内容が生成されます ===\n")
        print(final_content[:500])
        print("\n...")
        print(f"\n合計文字数: {len(final_content)}")
    else:
        output_file.write_text(final_content, encoding='utf-8')
        print(f"✅ 結合完了: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='卒論マークダウン分割・結合スクリプト',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    subparsers = parser.add_subparsers(dest='command', help='コマンド')

    # split コマンド
    split_parser = subparsers.add_parser('split', help='mdファイルをフォルダ構造に分割')
    split_parser.add_argument('input_file', help='入力mdファイル (例: 1127.md)')
    split_parser.add_argument('output_dir', help='出力ディレクトリ名 (例: 01)')
    split_parser.add_argument('--version', '-v', default='v1', help='バージョンプレフィックス (デフォルト: v1)')
    split_parser.add_argument('--dry-run', '-n', action='store_true', help='実行せずに構造を確認')

    # merge コマンド
    merge_parser = subparsers.add_parser('merge', help='フォルダ構造を単一mdファイルに結合')
    merge_parser.add_argument('input_dir', help='入力ディレクトリ (例: 01)')
    merge_parser.add_argument('output_file', help='出力mdファイル (例: output.md)')
    merge_parser.add_argument('--dry-run', '-n', action='store_true', help='実行せずに内容を確認')

    # show コマンド（構造表示）
    show_parser = subparsers.add_parser('show', help='mdファイルの構造を表示')
    show_parser.add_argument('input_file', help='入力mdファイル')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    # スクリプトのあるディレクトリを基準にする
    script_dir = Path(__file__).parent

    if args.command == 'split':
        input_path = script_dir / args.input_file
        output_path = script_dir / args.output_dir

        if not input_path.exists():
            print(f"エラー: 入力ファイルが見つかりません: {input_path}")
            return

        content = input_path.read_text(encoding='utf-8')
        parsed = parse_markdown_structure(content)
        structure = build_folder_structure(parsed, args.version)

        print(f"📄 入力ファイル: {input_path}")
        print(f"📁 出力先: {output_path}")
        print(f"🏷️  バージョン: {args.version}")
        print()

        write_structure_to_disk(structure, output_path, args.version, args.dry_run)

    elif args.command == 'merge':
        input_path = script_dir / args.input_dir
        output_path = script_dir / args.output_file

        if not input_path.exists():
            print(f"エラー: 入力ディレクトリが見つかりません: {input_path}")
            return

        merge_structure_to_file(input_path, output_path, args.dry_run)

    elif args.command == 'show':
        input_path = script_dir / args.input_file

        if not input_path.exists():
            print(f"エラー: 入力ファイルが見つかりません: {input_path}")
            return

        content = input_path.read_text(encoding='utf-8')
        parsed = parse_markdown_structure(content)

        print(f"📄 {input_path}\n")
        print("=== 見出し構造 ===\n")

        for section in parsed['sections']:
            indent = '  ' * (section['level'] - 1)
            prefix = '#' * section['level']
            has_content = '📝' if section['content'] else '  '
            print(f"{has_content} {indent}{prefix} {section['title']}")


if __name__ == '__main__':
    main()
