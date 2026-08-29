# -*- coding: utf-8 -*-
"""assets/characters の 4K テクスチャを 2048 に落とす指定を掛け直す。

  python3 tools/limit_character_texture_size.py
  <Godot> --headless --path . --editor --quit    # 掛けたあと再インポート

Mixamo の FBX はテクスチャを同じフォルダへ展開する。FBX が再インポートされると
展開し直しになり、テクスチャの .import も既定値へ戻る（size_limit=0）。
VRAM 圧縮の設定を変えたときなど、FBX ごと再インポートが走ったあとは、
これを流してから再インポートし直さないと配布物が 2 倍以上に膨らむ。

素の 4096 と 2048 の見た目の差は、ゲーム画面の約 2 倍に寄せた
tools/capture_characters.tscn の比較で最大 39/255・差分 4.18% だった。
"""
import glob
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIMIT = 2048

changed = 0
removed = 0
for png in sorted(glob.glob(os.path.join(ROOT, 'assets/characters/*.png'))):
    imp = png + '.import'
    if not os.path.exists(imp):
        continue
    if max(Image.open(png).size) <= LIMIT:
        continue
    src = open(imp, encoding='utf-8').read()
    if 'process/size_limit=' not in src:
        print('size_limit の項目が無い:', imp, file=sys.stderr)
        continue
    new = re.sub(r'process/size_limit=\d+', 'process/size_limit=%d' % LIMIT, src)
    if new == src:
        continue
    for dest in re.findall(r'res://\.godot/imported/[^"\]]+', src):
        p = os.path.join(ROOT, dest.replace('res://', ''))
        if os.path.exists(p):
            os.remove(p)
            removed += 1
    open(imp, 'w', encoding='utf-8').write(new)
    changed += 1

print('size_limit=%d を掛けた .import: %d 件 / 消したキャッシュ: %d 件' % (LIMIT, changed, removed))
