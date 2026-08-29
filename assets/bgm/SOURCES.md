# 面の音楽の取得元

すべて作者の自作曲。元は `Z:\music\自作曲` に置いてあるもので、面ごとに 1 曲を割り当てる。
5面ぶんだけ後半を切り出しており、それ以外はファイルをそのまま入れている。切り出しは
ffmpeg のストリームコピー（`-c copy`）で、再エンコードしていない。

| 出力 | 元ファイル | 切り出し | 長さ | Integrated loudness |
|---|---|---|---|---|
| `stage1.ogg` | `untitled02.ogg` | 全体 | 6:04 | -11.3 LUFS |
| `stage2.mp3` | `untitled.mp3` | 全体 | 5:04 | -8.7 LUFS |
| `stage3.ogg` | `untitled01.ogg` | 全体 | 9:05 | -9.1 LUFS |
| `stage4.ogg` | `untitled03.ogg` | 全体 | 2:56 | -10.6 LUFS |
| `stage5.ogg` | `untitled01.ogg` | 6:19 から終わりまで | 2:46 | -8.9 LUFS |

`stage5.ogg` は `stage3.ogg` と同じ曲の後半で、3面で通しで聴いた曲が終盤だけ戻ってくる形になる。
ストリームコピーは Ogg のページ単位で切れるため、実際の開始点は指定した 6:19 より 0.013 秒だけ
手前になる。切り出した PCM は元の終端と 1 バイトまで一致することを確認している。

いずれも `loop=true` でインポートしている（`*.import` の `[params]`）。曲の終わりから頭へ
そのまま戻るので、繋ぎ目は作曲側の都合に任せている。

音量差は `BeltStage.bgm_volume_db` で均す。上表の integrated loudness を、いちばん小さい
1面（-11.3 LUFS）へ揃える値を各面に入れてある。
