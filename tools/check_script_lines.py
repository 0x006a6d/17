# -*- coding: utf-8 -*-
"""台本(nike_story_design.md §3)と levels/stage_N.tscn のカード文言を突き合わせる。

台本が正で、tscn 側がそれと1行ずつ一致するかだけを見る。演出のト書き（【】）と
区切り（---）・空行は台本側から落とす。tscn 側にだけ意図的に置いている行は EXTRA へ。

  python3 tools/check_script_lines.py
"""
import io, re, sys

DOC = 'nike_story_design.md'
# tscn にだけ置く行（台本では【】の演出だが、画面には地の文として出している）
EXTRA = {5: ['AIニケが床に落ちたポーランド国旗のヘアピンを拾う。自分の「AI」のヘアピンを外し、付け替える。']}


def load_blocks():
    doc = io.open(DOC, encoding='utf-8').read()
    body = doc.split('## 3. 台本')[1].split('## 4. 解説')[0]
    blocks, cur = {}, None
    for line in body.split('\n'):
        h = re.match(r'^### (.+)$', line)
        if h:
            cur = h.group(1).strip()
            blocks[cur] = []
            continue
        if cur is not None:
            blocks[cur].append(line)
    return blocks


def speech(lines):
    out = []
    for l in lines:
        t = l.strip()
        if not t or t == '---' or t.startswith('【') or '「' not in t:
            continue
        out.append(t)
    return out


def section(blocks, name, marker, to_end):
    """marker の次の行から。to_end なら節の終わりまで（途中の【】は読み飛ばす）、
    そうでなければ次の【】または --- まで。"""
    ls = blocks[name]
    start = next(i for i, l in enumerate(ls) if l.strip().startswith(marker)) + 1
    if to_end:
        return speech(ls[start:])
    end = len(ls)
    for i in range(start, len(ls)):
        t = ls[i].strip()
        if t.startswith('【') or t == '---':
            end = i
            break
    return speech(ls[start:end])


def tscn_lines(stage, key):
    s = io.open('levels/stage_%d.tscn' % stage, encoding='utf-8').read()
    m = re.search(r'(?m)^%s = Array\[String\]\(\[(.*)\]\)$' % key, s)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else []


def main():
    b = load_blocks()
    want = {
        1: (speech(b['オープニング']) + section(b, '1面：ターミナル・スラム', '【面頭・通信】', False),
            section(b, '1面：ターミナル・スラム', '【ボス撃破後・回想①】', True)),
        2: (section(b, '2面：タイムライン地下鉄', '【面頭・通信】', False),
            section(b, '2面：タイムライン地下鉄', '【ボス撃破後・回想②】', True)),
        3: (section(b, '3面：Discord湾岸', '【面頭・通信】', False),
            section(b, '3面：Discord湾岸', '【ボス撃破後・回想③】', True)),
        4: (section(b, '4面：工場', '【面頭・通信】', False),
            section(b, '4面：工場', '【ボス撃破後・ニケ登場', True)),
        5: ([], section(b, '5面：ポーランドの部屋', '【ニケ撃破・倒れる】', True)),
    }
    ng = 0
    for n in sorted(want):
        for key, w in (('opening_lines', want[n][0]), ('reveal_lines', want[n][1])):
            g = [l for l in tscn_lines(n, key) if l and l not in EXTRA.get(n, [])]
            if g == w:
                print('OK   stage_%d.%s  %d行' % (n, key, len(g)))
                continue
            ng += 1
            print('NG   stage_%d.%s' % (n, key))
            for i in range(max(len(g), len(w))):
                a = g[i] if i < len(g) else '(無し)'
                c = w[i] if i < len(w) else '(無し)'
                if a != c:
                    print('     [%d] tscn=%s' % (i, a))
                    print('         台本=%s' % c)
    print('不一致 %d 件' % ng)
    return 1 if ng else 0


if __name__ == '__main__':
    sys.exit(main())
