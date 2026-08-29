# -*- coding: utf-8 -*-
"""levels/stage_N.tscn のカード文言から nike_story_script.md を作り直す。

画面に出る文言の正は tscn 側なので、台本を直したらこれを流して一覧を合わせる。

  python3 tools/build_story_script.py
"""
import io, re

OUT = 'nike_story_script.md'
STAGES = (1, 2, 3, 4, 5)

HEADER = """# 台本（ゲーム内の全会話）

各面の `levels/stage_N.tscn` に入っている `opening_lines`（面の冒頭）と `reveal_lines`（ボス撃破後）を、そのまま並べたもの。
ここが実際に画面に出る文言で、`nike_story_design.md` §3 は演出（【 】）を含む元の台本。両方を直す場合は設計書 §3 を正とする。

表示の規則: **1行が1枚のカード**。`名前「本文」` の行は話者付き、名前の無い行は地の文。空行と `---` は区切りで画面には出ない。
AIニケはタイル左・文章右、ニケとミカゼはタイル右・文章左。送りは Enter / Space / クリック / ○、スキップは Esc / △。
"""

SPEAKERS = ('AIニケ', 'ニケ', 'ミカゼ')


def field(text, key):
    m = re.search(r'(?m)^%s = Array\[String\]\(\[(.*)\]\)$' % key, text)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else []


def title(text):
    m = re.search(r'(?m)^stage_title = "(.*)"$', text)
    return m.group(1) if m else ''


def entry(line):
    """1行を（話者, 本文）に分ける。`名前「本文」` 以外は地の文。"""
    at = line.find('「')
    if at > 0:
        name = line[:at]
        if name in SPEAKERS and line.endswith('」'):
            return name, line[at + 1:-1]
    return '地の文', line


def render(lines):
    out, i = [], 0
    for line in lines:
        if not line:
            continue
        i += 1
        name, body = entry(line)
        out.append('%d. **%s** … %s' % (i, name, body))
    return out


def main():
    parts = [HEADER]
    for n in STAGES:
        text = io.open('levels/stage_%d.tscn' % n, encoding='utf-8').read()
        parts.append('\n## %d面 %s\n' % (n, title(text)))
        for key, label in (('opening_lines', '面の冒頭'), ('reveal_lines', 'ボス撃破後')):
            rows = render(field(text, key))
            if not rows:
                continue
            parts.append('\n### %s（`%s`）\n\n' % (label, key))
            parts.append('\n'.join(rows) + '\n')
    io.open(OUT, 'w', encoding='utf-8', newline='').write(''.join(parts))
    print('書き出した: %s' % OUT)


if __name__ == '__main__':
    main()
