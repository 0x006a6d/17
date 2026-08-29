# 背景画像（Codex 5.6 sol が生成）

ベルトスクロールのパララックス背景。`levels/belt_backdrop.gd` が、各面のシーンで指定した
`texture_path` の PNG をここから読んで奥に貼る。**ファイルを置くだけで反映される**（エディタ操作不要）。
ファイルが無い層は表示されず、今のプリミティブ背景のまま動く。

発注仕様は `docs/background-brief.md`。命名は `stage<N>_<layer>.png`。

| ファイル | 面 | 層 | 用途 |
| --- | --- | --- | --- |
| `stage1_far.png` / `stage1_mid.png` | 1 ターミナル・スラム | 遠景 / 中景 | 夜の古いターミナル街。中景の下辺は地面に接する |
| `stage2_far.png` / `stage2_mid.png` | 2 タイムライン地下鉄 | | 地下鉄のホームとトンネル |
| `stage3_far.png` / `stage3_mid.png` | 3 湾岸 | | 夕暮れの港湾 |
| `stage4_far.png` | 4 工場 | 遠景 | 組立工場の内部（1枚でよい） |
| `stage5_far.png` | 5 部屋 | 遠景 | 開発者の部屋（1枚でよい） |
| `stage<N>_ground.png` | 各面 | 床 | 4方向シームレスの床タイル |

このフォルダの PNG は生成物のため Git には含めない（`.gitignore`）。README とこの一覧は含める。
