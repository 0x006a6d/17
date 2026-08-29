# 効果音の取得元

すべて OpenGameArt の CC0 1.0（パブリックドメイン）素材から、必要な一撃ぶんを切り出して
44.1kHz / モノラル / 16bit へ揃えたもの。CC0 は著作権を放棄する宣言なので表示は義務ではないが、
作者への敬意として下に記す。加工は「区間の切り出し・モノラル化・音量の正規化・終端の
フェード」だけで、音そのものには手を加えていない。

| 出力 | 元ファイル | 切り出し | 作者 | 取得元 |
|---|---|---|---|---|
| `gun_shot.wav` | `22 Pistol.wav` | 0.13〜0.55秒（0.42秒ぶん。5発のうち1発目） | kurt | https://opengameart.org/content/gunshots |
| `rifle_shot.wav` | `AK-47/C_27P.wav` | 0.995〜2.095秒（1.10秒ぶん。5点バーストの最後の1発） | bart（The Free Firearm Sound Library） | https://opengameart.org/content/the-free-firearm-sound-library |
| `gun_dry.wav` | `equipment_clicks3.wav` | 7.985〜8.085秒（0.10秒ぶん。クリック1つ） | lfa | https://opengameart.org/content/equipment-clicks-iii |
| `gun_reload.wav` | `reload.wav` | 0.08〜1.38秒（1.30秒ぶん。弾倉を抜いて差し、スライドを引くまで） | zer0sol | https://opengameart.org/content/handgun-reload-sound-effect |
| `hit_punch.wav` | `hits/hit30.mp3.flac` | 0.135〜0.446秒（0.31秒ぶん） | supergamez2014（Independent.nu ljudbank） | https://opengameart.org/content/37-hitspunches |
| `hit_kick.wav` | `hits/hit10.mp3.flac` | 0.052〜0.298秒（0.25秒ぶん） | supergamez2014（Independent.nu ljudbank） | https://opengameart.org/content/37-hitspunches |
| `hit_finish.wav` | `hits/hit17.mp3.flac` | 0.127〜0.375秒（0.25秒ぶん） | supergamez2014（Independent.nu ljudbank） | https://opengameart.org/content/37-hitspunches |
| `katana_slash.wav` | `battle/swing.wav` | 0.00〜0.45秒（無音を除いた実長 0.23秒） | artisticdude | https://opengameart.org/content/rpg-sound-pack |
| `enemy_down.wav` | `impact.2.ogg` | 0.11〜0.51秒（0.40秒ぶん） | StarNinjas | https://opengameart.org/content/10-impact-shield-blocks |

素手の命中音は技ごとに3本に分けている。ジャブ・ストレートが `hit_punch`、膝・ミドルが
`hit_kick`、締めのフック・ハイが `hit_finish`。以前は 1 本（`thwack-05.wav` 切り出し）を
6技すべてで鳴らしていたが、低域が 94% を占めて中高域がほとんど無く、技の差も出なかったので
差し替えた。`37 hits/punches` の中身は mp3 由来の flac なので 16kHz 以上は入っていない。

命中の間隔は melee/kick クリップ長 × out_ratio で決まり、実測でジャブ 0.243秒 /
ストレート 0.328秒 / フック 0.428秒 / 膝 0.516秒 / ミドル 0.509秒 / ハイ 0.438秒
（ヒットストップ 0.09秒が各回加わる）。パンチ側の素材はこの間隔に収まる長さで切っている。

`rifle_shot.wav` の元は自動小銃の5点バーストの録音で、最後の1発（次まで 4.7秒空く）だけを切り出した。
ゲーム側は 0.18秒間隔で5発撃つので、この1発ぶんを続けて鳴らす。録音のバースト間隔も 0.18秒。
ライブラリは銃種ごとのフォルダに分かれているが、ゲーム内の表記は「9mmオート」等の一般名のままにする。

いずれも配布ページのライセンス表示が CC0 1.0 であることを確認している。zip 同梱の
ライセンス文書があるものは中身も確認した。`independent_nu_ljudbank-hits_and_punches.7z` には
ライセンス文書が同梱されておらず、配布ページの CC0 1.0 表示だけが根拠になる。

採用を見送ったもの: OpenGameArt 上では CC0 と表示されているが、zip 同梱の
`creativecommons.txt` が CC-BY 3.0 だった素材（`gunshot-sounds` / tabasco）。表示と中身が
食い違うため使わない。

`gun_reload.wav` の長さ 1.30秒に合わせて `PlayerWeapon.reload_duration` も 1.3 にしてある。

以前は `tools/build_sfx.py` で合成した自作波形を使っていた（生成器は git 履歴に残る）。
