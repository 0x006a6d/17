# -*- coding: utf-8 -*-
"""assets/fonts のフォントを、このプロジェクトで実際に使う文字だけに絞り直す。

配布物そのままの Shippori Mincho B1 ExtraBold は 15MB（15363 字）あるが、
ゲームに出る文字は 1000 字程度しかないので、残りは持たない。

  python3 tools/build_font_subset.py <配布物の ShipporiMinchoB1-ExtraBold.ttf>

台詞や UI 文言を足したあとは流し直す。流し忘れると、増えた文字だけ
Godot の allow_system_fallback で別のフォントに落ちて字面が変わる。

必要: fonttools（pyftsubset）。

残す文字:
  1. プロジェクト内の .gd/.tscn/.tres/.gdshader の文字列リテラルに出る全文字
  2. ASCII 印字可能・仮名・約物・全角英数（後から文言を足したときの取りこぼし避け）
  3. HINTING_REFS

HINTING_REFS は FreeType の CJK オートヒンターがベースライン位置を決めるのに読む
基準グリフ。画面には出ないが、欠けると同じサイズでも他の漢字のグリッド合わせが
ずれて、配布物と 1px 単位で描画が変わる。delta debugging で特定した最小集合。
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'assets/fonts/ShipporiMinchoB1-ExtraBold.ttf')
SKIP_DIRS = {'.godot', '.git', 'addons'}
EXTS = ('.gd', '.tscn', '.tres', '.gdshader')
HINTING_REFS = '个些們嗘愿田能說錣駧'

# GDScript は " と ' の両方を文字列に使える。シェーダ本体の """…""" も
# 外側の "" が空文字列として拾われるだけなので、この2つで足りる。
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"' + r"|'((?:[^'\\]|\\.)*)'")


def used_chars():
    out = set()
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(EXTS):
                continue
            try:
                text = open(os.path.join(dirpath, fn), encoding='utf-8').read()
            except UnicodeDecodeError:
                continue
            for m in LITERAL.finditer(text):
                out.update(m.group(1) or m.group(2) or '')
    return out


def base_chars():
    out = set(chr(c) for c in range(0x20, 0x7F))          # ASCII 印字可能
    out |= set(chr(c) for c in range(0x3000, 0x3100))     # 約物・ひらがな・カタカナ
    out |= set(chr(c) for c in range(0x31F0, 0x3200))     # カタカナ拡張
    out |= set(chr(c) for c in range(0xFF01, 0xFFA0))     # 全角英数・記号・半角カナ
    out |= set('°±×÷…→←↑↓≈∞※〒♪♥★☆♂♀')
    return out


def main(src):
    # 差し替え済みのリポジトリ内 ttf を入力に渡すと、抜き出し済みのものを
    # さらに抜き出して黙って字を落とすので、入力は配布物だけを受ける。
    if os.path.realpath(src) == os.path.realpath(DEST):
        sys.exit('入力に %s は使えない。配布物の ttf を渡す。' % DEST)
    keep = (used_chars() | base_chars() | set(HINTING_REFS)) - set('\r\n\t')
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False,
                                     encoding='utf-8') as fh:
        fh.write(''.join(sorted(keep)))
        chars_file = fh.name
    try:
        subprocess.run([
            sys.executable, '-m', 'fontTools.subset', src,
            '--output-file=' + DEST,
            '--text-file=' + chars_file,
            '--layout-features=*',
            '--glyph-names', '--symbol-cmap', '--legacy-cmap',
            '--notdef-glyph', '--notdef-outline',
            '--name-IDs=*', '--name-legacy', '--name-languages=*',
        ], check=True)
    finally:
        os.unlink(chars_file)
    print('%d chars -> %s (%d bytes, source %d bytes)'
          % (len(keep), DEST, os.path.getsize(DEST), os.path.getsize(src)))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
