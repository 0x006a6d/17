# アセットクレジットと素材の取得手順

外部から取得したアセットの出典・ライセンスと、同じものを手元に揃える手順。

再配布できない素材はリポジトリに含めていない。`.import` と BoneMap の `.tres` は含めてあるので、
下表と同じファイル名で同じ場所へ置けば、Godot で開き直すだけでリターゲットまで通る。

| 種類 | 置き場 | リポジトリ | 用意のしかた |
| --- | --- | --- | --- |
| AIニケちゃんの公式 VRM | `assets/vrm/nikechan_player.vrm` | 含めない | 公式アセットリポジトリから取得する |
| Mixamo のキャラクター・モーション | `assets/characters/` / `assets/motions/` | 含めない（`.import` と BoneMap は含む） | Mixamo から各自で取得する |
| 公式サイトの三面図（立ち絵） | `assets/portraits/*.png` | 含めない | `tools/fetch_assets.sh` で取得する |
| 背景・床の画像 | `assets/backgrounds/*.png` | 含めない | 無いと背景の板と床のテクスチャが出ない（ゲーム自体は動く） |
| 武器モデル・VFX テクスチャ・効果音・掛け声・フォント・BGM・タイトル画像 | `assets/weapons` ほか | 含める | 不要 |
| プレイヤーの攻撃クリップ | `actors/player/anim/*.res` | 含める（ベイク済み） | 作り直すときだけ元の FBX が要る |

VRM とキャラクターの FBX が無いと人物が出ないので、クローンしただけでは遊べない。`docs/img/qc_*.png`
（各 capture ツールが書き出す確認用の画像）もリポジトリには含めていない。

## VRM: AIニケちゃん公式モデル

- ファイル: `assets/vrm/nikechan_player.vrm`（公式の `vrms/nikechan_v2.vrm` をこの名前で置く）
- 取得元: https://github.com/tegnike/nikechan-assets
- ライセンス: ニケ二次創作ガイドライン（https://nikechan.com/guidelines/derivative）の範囲。
  公式 IP 資産の再ホスティングを避けるためリポジトリに含めない
- 用途: プレイヤー、5面のニケ、4面で盾にされる身体、5面の増援の1体。ヘアピンの非表示と
  シャツの色替えは `actors/boss/nike_skin.gd` がランタイムに行い、VRM ファイル自体は改変しない
- 導入: `godot-vrm`（V-Sekai。`addons/vrm`）でインポートする。Mixamo のモーションは
  `SkeletonProfileHumanoid` へリターゲットして共通で当てる

## Mixamo（キャラクター・モーション）

- 出典: Mixamo（https://www.mixamo.com、Adobe 提供）
- ライセンス: Adobe General Terms of Use。自分の制作物への組み込み利用は可（ゲーム・映像等）。
  一方で、モーションを Mixamo 由来のスタンドアロンなアセットとして単体再配布（素材ファイル
  そのものの配布・転売）することは不可。このため `assets/motions/mixamo_*.fbx` と
  `assets/characters/mixamo_*.fbx`（＋インポータが同フォルダへ展開する `mixamo_*.png`）は
  リポジトリに含めていない
- 形式: 各 FBX に 1 アニメ（Godot の ufbx が sanitize して `mixamo_com` 名になる）

### ダウンロード設定

| 対象 | 設定 |
| --- | --- |
| キャラクター本体 | FBX For Unity / **With Skin** |
| モーション | FBX For Unity / **Without Skin** |

キャラクターはメッシュを得るためのダウンロードなので、同梱されるアニメーションは何でもよい
（`ChNN_nonPBR@Flip Kick.fbx` 等の名前で落ちてくる）。ゾンビの `Ch30` と `Ch18` だけは
`Zombie Attack` を付けて落とし、`Ch30` はメッシュと攻撃モーションの両方をその 1 本から取る。

### キャラクター

`assets/characters/mixamo_chNN.fbx` に置く（`ChNN` は Mixamo のキャラクター番号）。

| Mixamo | 配置ファイル | 役 | 見た目 | メッシュ | 頂点数 | 身長 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| Ch01_nonPBR | `mixamo_ch01.fbx` | 雑魚（通常型の基本） | 白ポロシャツ・青ジーンズ・スキンヘッド | 5 | 23,623 | 1.764 m |
| Ch06_nonPBR | `mixamo_ch06.fbx` | 雑魚 | — | — | — | — |
| Ch08_nonPBR | `mixamo_ch08.fbx` | 突進型（`roles/rusher.tscn`） | 白パーカー・白スウェット・顎髭 | 7 | 35,568 | 1.781 m |
| Ch28_nonPBR | `mixamo_ch28.fbx` | 雑魚・`bruiser.tscn` の基底 | 黒の長袖・黒パンツ | 6 | 36,725 | 1.763 m |
| Ch35_nonPBR | `mixamo_ch35.fbx` | 1面ボス マスクマン | — | — | — | — |
| Swat | `mixamo_swat.fbx` | 2面ボス SWAT | — | — | — | — |
| Ch15_nonPBR | `mixamo_ch15.fbx` | 3面ボス GUNNER | — | — | — | — |
| Ch16_nonPBR | `mixamo_ch16_boss.fbx` | 4面ボス マッドサイエンティスト | — | — | — | — |
| Ch30_nonPBR | `mixamo_ch30.fbx` | 4面ボス戦に加わるゾンビ | — | 1 | 19,906 | 1.754 m |
| Ch18_nonPBR | `mixamo_ch18.fbx` | 5面でラスボスを守る敵 | — | 1 | 23,943 | 1.751 m |
| Ch16_nonPBR | `mixamo_ch16.fbx` | 面からは参照しない（QC 用） | 水色の術衣・サージカルマスク・キャップ | 7 | 31,886 | 1.774 m |

### モーション（実行時に必要な31本）

`assets/motions/` に置く。プレイヤーの素手コンボは `actors/player/anim/*.res` にベイク済みなので、
この31本があればゲームは動く。

| Mixamo 検索名 | 配置ファイル | 用途 |
| --- | --- | --- |
| Idle | `mixamo_idle.fbx` | プレイヤー・敵の待機（2.200s / 53 トラック） |
| Walking | `mixamo_walk.fbx` | 敵の歩行 |
| Running | `mixamo_run.fbx` | プレイヤー・敵の走行 |
| Medium Step Forward | `mixamo_step_forward.fbx` | プレイヤーの歩行。構えたまま前へ出る |
| Head Spinning | `mixamo_dance_headspin.fbx` | 回復ダンス（0.833s / 53 トラック） |
| Standing Death Backward 01 | `mixamo_death_backward_01.fbx` | プレイヤーのダウン（仰向け。2.567s / 54 トラック） |
| Kip Up | `mixamo_kip_up.fbx` | プレイヤーの立ち上がり |
| Medium Hit To Head | `mixamo_hit_head.fbx` | 敵の被弾のけぞり |
| Standing React Large From Front | `mixamo_hit_react_large_front.fbx` | 敵のノックバック |
| Standing React Small From Right | `mixamo_hit_react_small.fbx` | 敵の軽い被弾と、プレイヤーの上半身被弾レイヤー |
| Cross Punch | `mixamo_cross_punch.fbx` | 敵の近接（右ストレート） |
| Lead Jab | `mixamo_jab_left.fbx` | 敵の近接（ジャブ） |
| Hook（バリエーション 1） | `mixamo_hook_1.fbx` | 敵の近接（フック） |
| Death Crouching Headshot Front | `mixamo_death_headshot.fbx` | 敵・1〜5面ボスの死亡 |
| Dying | `mixamo_dying.fbx` | 4面の身体の伏せ（最終フレームで静止） |
| Zombie Idle | `mixamo_zombie_idle.fbx` | 4面の雑魚の待機（4.000s） |
| Walking（Ch30 で書き出し） | `mixamo_zombie_walk.fbx` | 4面の雑魚の歩き（4.033s） |
| Zombie Attack | `mixamo_zombie_attack.fbx` | 4面の雑魚の攻撃（2.633s） |
| Shooting | `mixamo_pistol_fire.fbx` | 拳銃の構え（静止）と発砲。プレイヤーと4面ボス（1.17s） |
| Pistol Walk | `mixamo_pistol_walk.fbx` | 拳銃の構え歩き |
| Pistol Run Arc | `mixamo_pistol_run.fbx` | 4面ボスの走り |
| Rifle Aiming Idle | `mixamo_rifle_idle.fbx` | 3面ボスの待機（3.10s） |
| Walking（Shooter Pack） | `mixamo_rifle_walk.fbx` | 3面ボスの歩き（1.37s） |
| Rifle Run | `mixamo_rifle_run.fbx` | 3面ボスの走り（0.73s） |
| Firing Rifle | `mixamo_rifle_fire.fbx` | 3面ボスの発砲（1.17s） |
| Sword And Shield Slash | `mixamo_sword_slash.fbx` | 日本刀の初段 |
| Standing Melee Attack Horizontal | `mixamo_melee_horizontal.fbx` | 日本刀の二段（横薙ぎ） |
| Standing Melee Attack 360 Low | `mixamo_katana_360.fbx` | 日本刀の三段 |
| Standing Idle | `mixamo_sword_idle.fbx` | 日本刀を装備中の待機 |
| Backflip | `mixamo_dodge_backflip.fbx` | 回避（2.167s のうち 0.600〜1.400s を使う） |
| Spin Flip Kick | `mixamo_spin_flip_kick.fbx` | △必殺 |

### モーション（攻撃クリップを再ベイクする場合の6本）

`tools/build_melee_anims.gd` が読む材料。`actors/player/anim/*.res` を作り直すときだけ要る。

| Mixamo 検索名 | 配置ファイル | ベイク先 | 技 |
| --- | --- | --- | --- |
| Lead Jab | `mixamo_jab_left.fbx` | `melee_1` | 左ジャブ |
| Cross Punch | `mixamo_cross_punch.fbx` | `melee_2` | 右ストレート |
| Hook（バリエーション 4） | `mixamo_hook_4.fbx` | `melee_3` | 左フック |
| Illegal Knee | `mixamo_knee.fbx` | `kick_1` | 右膝 |
| Kicking | `mixamo_kick_finish.fbx` | `kick_2` | 右ミドル |
| Mma Kick | `mixamo_kick_mma.fbx` | `kick_3` | 右ハイ |

Hook は Mixamo 上で同名の複数バリエーションがあり、ダウンロード時に `(1)` `(2)` 等の連番が付く。
連番の若い順に `mixamo_hook_1..4` を割り当てており、プレイヤーの左フックは 4 番目、敵のフックは
1 番目を使う。

### リポジトリに `.import` だけがある未使用のファイル

計測・比較のために取得したもので、ゲームは参照しない。揃えなくても動く。

`mixamo_pistol_kneel_idle` / `mixamo_sword_attack` / `mixamo_club_combo` / `mixamo_grab_slam` /
`mixamo_pickup` / `mixamo_zombie_attack_blank` / `mixamo_walk_female` / `mixamo_walk_catwalk` /
`mixamo_boxing_idle` / `mixamo_backslide` / `mixamo_dive_roll` / `mixamo_dodge_backward` /
`mixamo_fall_land_idle` / `mixamo_grenade_throw` / `mixamo_elbow_1..3` / `mixamo_hook_2..3` /
`mixamo_hit_react_1` / `mixamo_hit_react_large_right` / `mixamo_kick_*`（chapa / high_left /
martelo / roundhouse / side / soccer / standing）/ `mixamo_knee_jab` / `mixamo_punch_combo` /
`mixamo_combo_punch` / `mixamo_death_*`（back_01 / dying / forward_01 / front_01 / left_01）/
`mixamo_ch16.fbx`

### スケルトン命名と BoneMap

Mixamo 元来の命名は `mixamorig:Hips` だが、Godot 4.7 の ufbx インポータがコロンを `_` に
sanitize する。さらに接頭辞の数字はダウンロードごとに変わりうるため、接頭辞ごとに BoneMap を
分けてある。**手元に落としたファイルの接頭辞が下表と違う場合は、BoneMap を作り直す。**

| 接頭辞 | 対象 | BoneMap |
| --- | --- | --- |
| `mixamorig4_` | Walking / Running / Standing Death Backward 01 ほか | `assets/motions/mixamo_bone_map.tres` |
| `mixamorig1_` | Head Spinning / Idle | `assets/motions/mixamo_bone_map_rig1.tres` |
| `mixamorig_`（数字なし） | Medium Hit To Head / Dying / Medium Step Forward / Kip Up、Shooter Pack の4本、ゾンビの3本、Shooting、および ch15 / ch16_boss / ch35 / swat | `assets/motions/mixamo_bone_map_rig0.tres` |
| `mixamorig6_` | 日本刀・回避・必殺・拳銃など Ch20@ 由来のモーション | `assets/motions/mixamo_bone_map_rig6.tres` |
| `mixamorig9_` | ch06 | `assets/motions/mixamo_bone_map_rig9.tres` |
| `mixamorig12_` | ch01 | `assets/characters/mixamo_bone_map_ch01.tres` |
| `mixamorig7_` | ch08 | `assets/characters/mixamo_bone_map_ch08.tres` |
| `mixamorig10_` | ch28 | `assets/characters/mixamo_bone_map_ch28.tres` |
| `mixamorig_`（数字なし） | ch16 | `assets/characters/mixamo_bone_map_ch16.tres` |

接頭辞が一致しない BoneMap を当てるとリターゲットが通らず、ボーン名が `mixamorig1_*` のまま残る。
新しい素材を足す際は次で BoneMap を生成する（引数はスペース区切り。`--prefix=...` の形式は
受け付けない）。

```
tools/generate_mixamo_bone_map.gd -- --prefix <接頭辞> --output <保存先>
```

接頭辞が既知の BoneMap と同じなら、取り込みは `tools/add_mixamo_motion.sh` が一括で行う。

```
tools/add_mixamo_motion.sh "Ch35_nonPBR@Dying.fbx" mixamo_dying \
  res://assets/motions/mixamo_bone_map_rig0.tres
```

キャラクター側のインポート設定は `assets/motions/mixamo_walk.fbx.import` と同じ
（`apply_node_transforms` / `overwrite_axis` / `normalize_position_tracks` を有効、
`fix_silhouette` は無効）。各キャラは 65 ボーンで 52 ボーンがマップされ、必須ボーンの欠落は無い。
リターゲット後はスケルトン名が `GeneralSkeleton`、ボーン名が `Hips` / `Head` などのプロファイル名に
なり、どのモーション FBX もそのまま適用できる。検証は `tools/test_character_anim.gd`
（全キャラ × 全モーションのトラック解決・姿勢変化・ルートモーション潰し）と
`tools/check_mixamo_skeleton.gd`（スケルトン構成の一致）。

Y Bot（Mixamo の素体）は自前のキャラクターを使うため取り込まない。

### ルートモーション

位置は `CharacterBody3D` が持つので、クリップが体を運ぶと見た目と当たり判定がずれる。
Mixamo の "In Place" で落とせなかったクリップは、読み込み後に
`RootMotion.lock_horizontal()`（`actors/shared/root_motion.gd`）で Hips の水平成分を潰す。
NPC 側は `NpcAnimator.lock_root_motion`（既定 on）が全クリップに適用する。

| クリップ | 水平移動 |
| --- | ---: |
| `mixamo_walk` / `mixamo_run` | 0 m（In Place） |
| `mixamo_pistol_walk` | 0 m（In Place） |
| `mixamo_sword_idle` / `mixamo_pickup` | 0 m（In Place） |
| `mixamo_rifle_idle` | 0 m（In Place） |
| `mixamo_dying` | 0.33 m |
| `mixamo_step_forward` | 0.93 m |
| `mixamo_rifle_walk` | 1.31 m |
| `mixamo_death_backward_01` | 1.37 m |
| `mixamo_rifle_run` | 2.13 m |

### 実測値

`tools/measure_stride.gd` ほかで計測した値。`NpcAnimator` や `EnemyAttackProfile` に入れてある。

| クリップ | 長さ | 1歩 | natural speed |
| --- | ---: | ---: | ---: |
| `mixamo_walk` | — | — | 1.537 m/s |
| `mixamo_zombie_walk` | 4.033s | 0.708 m | 0.351 m/s |
| `mixamo_rifle_walk` | 1.367s | 0.615 m | 0.90 m/s |
| `mixamo_rifle_run` | 0.733s | 0.911 m | 2.48 m/s |
| `mixamo_pistol_walk` | — | — | 2.09 m/s |

`mixamo_zombie_attack` は手が最も前に出るのが 1.132s（全長 2.633s）。`EnemyAttackProfile` の
`measured_peak_time` / `source_clip_length` はこの値。Zombie Attack は Ch30 / Ch18 / Y Bot の
どのリグで書き出しても長さと打撃ピークが一致する。歩幅が遅いので、ゾンビの `chase_speed` は
1.05 m/s、`depth_align_speed` は 1.0 m/s に落としてある（既定の 3.2 / 2.2 のままだと足が滑る）。

`mixamo_pistol_fire`（Shooting）の中身は発砲1回ぶんの反動で、0.000〜0.130s は静止、
0.42〜0.52s が反動の頂点、末尾で構えへ復帰する（先頭と末尾の Hips が完全一致）。Hips 水平変位は
X 0.009 m / Z 0.016 m、Hips 高さ 0.894 m。右手の総移動量は Y 0.027 m / Z 0.036 m / X 0.015 m。
ゲーム上では構えの60フレームで右手・武器原点・銃口が同じ値、発砲で銃口先端が X −0.073 m 後退・
Y +0.038 m 跳ね上げ、約 1.07 秒で構えへ戻る（`docs/img/qc_gunidle_*.png` / `qc_gunfire_*.png`）。

### 既知の問題

- Ch28 の顔が崩れている。眼球が瞼から突き出し、口が開いたままになる。髪・まつ毛メッシュを
  非表示にしても残るので Body メッシュ側の問題であり、リターゲット前のインポート直後から同じ状態。
  他のキャラでは起きていない。確認は `tools/capture_characters.gd`
  （`--only Ch28 --distance 0.8 --height 1.6`）
- Ch01 / Ch16 / Ch28 は FBX に埋め込まれたテクスチャが 1〜2 セットしか無く、髪・まつ毛の
  マテリアルに body の diffuse が割り当てられる。Ch08 だけは髪用テクスチャ（2048px）を持つ

## 武器モデル: Poly Pizza（CC0）

手に持たせる武器の 3D モデル。すべて CC0 1.0（パブリックドメイン。帰属義務なし・商用可・改変可）。
CC0 なのでリポジトリに含めてある（数十〜百数十 KB）。出典の詳細は `assets/weapons/SOURCES.md`。

| ファイル | モデル | 作者 | 取得元 |
| --- | --- | --- | --- |
| `assets/weapons/pistol.glb` | Pistol | Quaternius | https://poly.pizza/m/J3i9KDQ3kt |
| `assets/weapons/katana.glb` | Katana | CreativeTrio | https://poly.pizza/m/9CCcEXCUZH |
| `assets/weapons/rifle.glb`（3面ボス） | Assault Rifle | Quaternius | https://poly.pizza/m/K2lXTYFSLC |
| `assets/weapons/grenade.glb`（実行時参照なし） | Grenade | Quaternius | https://poly.pizza/m/xnuUzBTsUg |

`rifle.glb` は `pistol.glb` と同じ Ultimate Guns Pack
（https://poly.pizza/bundle/Ultimate-Guns-Pack-cpgUfI4t2F）から取ってあり、配色と作りが揃う
（頂点 2,512 / 三角 1,304、素の全長 5.422）。Poly Pizza 上の名称は "Assault Rifle" で実銃名では
なく、ゲーム内の表記も「9mmオート」等の一般名に留める。

## VFX テクスチャ: Particle Pack（Kenney、CC0）

- ファイル: `assets/fx_textures/kenney/*.png`（96枚）＋ 同梱 `LICENSE.txt`
- 作者: Kenney（https://kenney.nl）
- ライセンス: CC0 1.0 Universal。同梱 License.txt 原文を `assets/fx_textures/kenney/LICENSE.txt`
  として保存
- 取得元: https://kenney.nl/assets/particle-pack （公式配布 zip）
- 内容: 半透明 VFX スプライト（slash / muzzle / spark / flame / flare / smoke / scorch / star /
  trace / twirl / light / dirt / circle / magic ほか）。ヒットエフェクト・銃弾ヒット等に使う

## 効果音: OpenGameArt（CC0）

- ファイル: `assets/sfx/*.wav`（9本、44.1kHz / 16bit / モノラル）
- 出典: すべて OpenGameArt の CC0 1.0。作者・元ファイル・切り出し位置は `assets/sfx/SOURCES.md`
  に一覧がある。CC0 は表示が義務ではないが、作者名は同ファイルに記す
- 加工: 必要な一撃ぶんの切り出し、モノラル化、音量の正規化、終端 8〜10ms のフェードのみ
- 再生: `autoload/sfx.gd`（`Sfx.play(&"gun_shot")`）。AudioStreamPlayer を10本持ち回し、
  再生ごとに音程を ±6% ばらつかせて連打が機械的に聞こえないようにする

| ファイル | 長さ | 作者 | 鳴らす場面 |
| --- | ---: | --- | --- |
| `gun_shot.wav` | 0.42s | kurt | プレイヤーが撃ったとき（`PlayerWeapon.fired`） |
| `gun_dry.wav` | 0.10s | lfa | 残弾0で撃ったとき（`dry_fired`） |
| `gun_reload.wav` | 1.30s | zer0sol | リロード開始（`reload_started`） |
| `hit_punch.wav` | 0.31s | supergamez2014 | ジャブ・ストレートが当たったとき |
| `hit_kick.wav` | 0.25s | supergamez2014 | 膝・ミドルが当たったとき |
| `hit_finish.wav` | 0.25s | supergamez2014 | 締めのフック・ハイが当たったとき（`finish_volume_db` で +2dB） |
| `katana_slash.wav` | 0.23s | artisticdude | 日本刀を振ったとき（`PlayerKatanaCombo.stage_started`） |
| `enemy_down.wav` | 0.38s | StarNinjas | 敵が倒れたとき（`Enemy._on_downed`） |
| `rifle_shot.wav` | 1.10s | The Free Firearm Sound Library | 3面ボスが撃ったとき（`GunBoss._on_shot_fired`）。5発のバーストで1発ごとに鳴る |

素手の命中音は技で分ける。判別は `PlayerMelee.stage_started`、再生は命中の瞬間
（`MeleeHitbox.hit_landed`）で、割り当ては `PlayerSfx` の `@export` から差し替えられる。
`hit_landed` は当たった相手ごとに出るので、`PlayerSfx` 側で 1 物理フレーム 1 回に抑えている
（複数体を巻き込んだときに同じ波形が重なって音量が跳ねるのを避ける）。
`gun_reload.wav` の長さに合わせて `PlayerWeapon.reload_duration` を 1.3 秒にしてある。
検証は `godot --path . --headless res://tools/test_player_sfx.tscn`。

OpenGameArt の表示が CC0 でも、zip 同梱の `creativecommons.txt` が CC-BY 3.0 のものがある
（`gunshot-sounds` / tabasco）。表示と中身が食い違う素材は使わない。

## 掛け声: 自作

- ファイル: `assets/voice/*.wav`（9本、48kHz / 16bit / モノラル）
- 出典: 外部素材を使わず、ローカルで動かした Irodori-TTS
  （`Aratako/Irodori-TTS-600M-v3-VoiceDesign`、コードは MIT）に、こちらで書いたテキストと
  声色の指定を与えて生成した。外部の音声素材も実在人物の声も使っていない（自作 = CC0 相当）
- 生成条件: `--num-steps 40`。AIニケちゃんの5本は先に作った1本を `--ref-wav` に指定して話者を
  固定し、敵の4本も同じやり方で1本へ揃えてある。前後の無音は生成後に削った
- 再生: `actors/shared/voice_reactions.gd`（`Health.staggered` / `Health.downed` を購読）

| ファイル | 台詞 | 長さ | 鳴らす場面 |
| --- | --- | ---: | --- |
| `ai_nike_hurt_a.wav` | うっ！ | 0.21s | AIニケちゃんの被弾 |
| `ai_nike_hurt_b.wav` | くっ…… | 0.24s | 同上 |
| `ai_nike_hurt_c.wav` | きゃっ | 0.46s | 同上 |
| `ai_nike_down_a.wav` | う……っ | 0.22s | AIニケちゃんのダウン |
| `ai_nike_down_b.wav` | あ…… | 0.39s | 同上 |
| `enemy_hurt_a.wav` | ぐっ | 0.61s | 敵の被弾 |
| `enemy_hurt_b.wav` | ぐぅっ | 0.83s | 同上 |
| `enemy_hurt_c.wav` | うおっ | 0.42s | 同上 |
| `enemy_down.wav` | がっ…… | 0.67s | 敵のダウン |

`assets/sfx/enemy_down.wav`（体が倒れる打撃音）とは別物。フォルダで区別する。

## フォント: Shippori Mincho B1 ExtraBold（SIL OFL 1.1）

- ファイル: `assets/fonts/ShipporiMinchoB1-ExtraBold.ttf`（配布物から使う文字だけを抜き出した
  もの。773KB。ライセンス全文は同じ階層の `OFL.txt`）
- 出典: Google Fonts / The Shippori Mincho Project Authors
  （https://github.com/fontdasu/ShipporiMincho）
- ライセンス: SIL Open Font License 1.1。同梱と改変は可、フォント単体の販売は不可、ライセンス文の
  同梱が条件。`OFL.txt` をリポジトリに含めてこれを満たす。Reserved Font Name の指定が無いので、
  抜き出したものも同じフォント名のまま使える
- 使う場所: ゲーム全体の既定フォント（`project.godot` の `gui/theme/custom_font`）。HUD・
  テキストカード・結果画面・面の題名がこれになる。擬音（`fx/attack_cry_3d.gd`）と、タイトルの
  `> enter`（`ui/enter_prompt.gd`。preload して直接描く）も同じ
- 収録は 982 字（配布物は 15363 字）。`∞` は配布物にも入っていないので、HUD の残機表示は
  「残機 ×無限」と書く
- 例外: カードの受信記録の体裁（`monospace_green`）だけ等幅を明示指定する（現状どの面も未使用）
- 抜き出しは `python3 tools/build_font_subset.py <配布物の ttf>` で作り直す。台詞や UI 文言を
  足したら流し直す。流し忘れると増えた文字だけ `allow_system_fallback` で別のフォントに落ちる
- 字面は配布物と変わらない。ゲームで使う 16/18/20/22/26/30/36/44/52/64px の全使用文字を Godot で
  描いて PNG 比較し、全サイズ差分 0 画素であることを確認してある。
  `tools/build_font_subset.py` の `HINTING_REFS` は、画面には出ないが欠けると FreeType の
  グリッド合わせがずれて他の漢字の描画が 1px 変わる基準グリフ

## 立ち絵: 三面図（AIニケちゃん公式サイト）

- ファイル: `assets/portraits/ainikechan_trihedral.png` / `nike_trihedral.png` /
  `mikaze_trihedral.png`（2048×1143）
- 取得元: https://nikechan.com/images/characters/trihedral_figures/{ainikechan,nikechan,mikaze}.png
  （`tools/fetch_assets.sh` で落とす）
- ライセンス: ニケ二次創作ガイドライン（https://nikechan.com/guidelines/derivative）の範囲。
  公式 IP 資産の再ホスティングを避けるためリポジトリに含めない
- 用途: テキストカードの話者タイル（顔の正方形を切り出して円形に表示）。無い場合はタイルの顔だけ
  空になり、ゲームは動く

## 計測ツール用: Universal Animation Library（Quaternius、CC0）

- ファイル: `assets/motions/universal_animation_library.gltf`（+ `.bin`）
- 作者: Quaternius（https://quaternius.com）
- ライセンス: CC0 1.0 Universal
- 取得元: https://github.com/J-Ponzo/gltf-universal-animation-library
  （Quaternius の Universal Animation Library Standard/無料版を itch.io
  https://quaternius.itch.io/universal-animation-library から取得し、glTF のみを再配布したもの）
- ライセンス根拠: リポジトリ同梱の `LICENSE` が CC0 1.0 の全文。README にも
  "This pack is licensed under CC0 1.0. Full details in LICENSE" と明記。Quaternius 公式ページ
  （https://quaternius.com/packs/universalanimationlibrary.html）でも
  "Free to use in personal, educational and commercial projects" / CC0 と表記
- 内容: 46 アニメーションを含む単一 glTF。実行時には使わず、QC・計測ツール専用。検証に使った
  攻撃モーションは `Punch_Cross`
- 参照ツール: `measure_punch.gd` / `measure_stride.gd` / `inspect_motion.gd` /
  `verify_retarget.gd` / `measure_combo_window.gd` / `probe_univ_names.gd` / `generate_bone_map.gd`
- スケルトン命名: Blender Rigify の DEF- 命名（例 `DEF-hips`, `DEF-spine.001`,
  `DEF-upper_arm.L`）。SkeletonProfileHumanoid へのリターゲットには BoneMap によるエイリアス解決が
  必要

## 武器の握り（実測値）

握りは固定角度ではなく、指の関節を武器の柄の表面へ当てる数値解法で決める（`technical-spec.md`
§14.5）。ここには武器モデル側の実測値を置く。

### 拳銃・日本刀（プレイヤーと2面・4面ボス）

| 項目 | 拳銃 | 日本刀 |
| --- | --- | --- |
| `grip_rotation` | `(0.2, -179.9, 64.5)`（構え）/ `(0.2, -179.9, 82.2)`（歩行） | `(10.5, -92.5, 171.1)` |
| `grip_offset` | `(0.0141, 0.0885, 0.0089)` | `(0.0737, 0.1084, 0.0351)` |
| `grip_scale` | `(0.12, 0.12, 0.12)` | `(0.40, 0.40, 0.50)` |
| `grip_axis_start` | `(0.0993, -0.1167, 0.0039)` | `(0.0015, 0.0028, 0.0799)` |
| `grip_axis_end` | `(0.0410, -0.4347, 0.0000)` | `(-0.0005, 0.0042, 0.2664)` |
| `grip_model_radius` | `0.133333` | `0.038` |

日本刀は拳に対して柄が太いため、柄・鍔の太さに当たるモデル X/Y だけを刀身方向（0.50）の 80% に
あたる 0.40 へ縮めてある。これで刀身長 0.72m を変えずに柄と鍔だけが細くなる。

拳銃は構えと歩行で腕の姿勢が違い、同じ角度だと銃身の向きが変わる。`PlayerWeapon` が本体の
速度から歩行ブレンドと同じ割合を求め、上表の2つを混ぜて、どちらの姿勢でも銃身を水平に保つ
（`technical-spec.md` §17.3）。4面ボスは同じ値で構えが −5.9 度（ほぼ水平）なので、混ぜずに
`WeaponLoadout` の1つを使う。VRM と Mixamo で手ボーンの姿勢が違うため、同じ握り値でも
結果が変わる。

### ライフル（3面ボス）

`tools/capture_rifle_grip.gd` が構えの姿勢から逆算する。銃の握りと handguard の2点を、構えの
右手・左手へ重ねる方式で、位置・向き・大きさが同時に決まる。

2点の取り方は次のとおり。座標で窓を切る方法は使わない。ローポリでは頂点が角にしか無く、
「面はあるのに頂点が無い帯」を空と誤判定するため。

- 握り（右手）: 受けの下（X -0.6..0.4 の Y<0）に入る頂点の重心
- handguard（左手）: マテリアル `Wood` のうち受けより前（X>1.0）が占める範囲の中央。重心では
  なく中央にするのは、この木部が後ろ側に頂点が多く（X 1.5..2.0 に 130 点、2.0..2.5 に 40 点）、
  重心だと手が木部の後端へ寄るため。マテリアル名は完全一致で見る（`contains` だと上部カバーの
  `DarkWood` も拾う）

合わせ先は手首ボーンではなく拳の中心（手首と指の付け根の中点）。実測で 6.3 cm 離れており、手首に
合わせると銃がそのぶん後ろへずれる。さらに `BoneAttachment` はスケルトンから 1.15 倍の拡縮を
受け継ぐので、`.tscn` に書く値はその内側として割っておく（割らないと銃が 1.15 倍に伸び、実測で
5.5 cm 過剰になる）。

| 項目 | 値 |
| --- | --- |
| `grip_rotation` | `(-4.3, 174.2, 74.5)` |
| `grip_offset` | `(0.0317, 0.0710, 0.0132)` |
| `grip_scale` | `0.1456`（両手 0.365 m ÷ モデル 2.18 ユニット ÷ 拡縮 1.15） |
| `grip_axis_start` | `(-0.1616, -0.1287, 0)` |
| `grip_axis_end` | `(-0.037, -0.2599, 0)` |
| `grip_model_radius` | `0.0742` |

`grip_axis_*` と `grip_model_radius` は右手の指を曲げる先（`PlayerWeaponGrip.set_grip_geometry`）
で、ライフルのメッシュから実測した握りの線分と太さ。拳銃の値のままだと指が見当違いの場所へ閉じる。

左手は `stage_3_boss.tscn` の `LeftGrip`（`actors/enemy/enemy_left_grip.gd` と
`enemy_left_grip_modifier.gd`）が曲げる。`player_weapon_grip_modifier.gd` はボーン名の定数が全部
`Right*` で右手しか触らないため、左手用を敵側へ分けてある。渡す値は木部の軸と太さで、これも実測。

| 項目 | 値 |
| --- | --- |
| `axis_start` | `(1.5043, 0.508, 0)` |
| `axis_end` | `(2.4871, 0.508, 0)` |
| `model_radius` | `0.1148`（断面 0.292 × 0.167 の平均半径） |

4本指は木部へ接地する（ソルバの残差 1〜3 cm）。親指は届かず 0 度で止まる。`thumb_curl_axis` の
符号を反転しても残差は 2〜4 cm のまま変わらないので、軸ではなくアニメーションの左手の開きが原因。
直すには手の姿勢を動かすことになり、0.2 mm で合わせた銃と手の位置関係を崩す。

ライフルのマテリアル別の部位（実測）。

| マテリアル | X | Y | 部位 |
| --- | --- | --- | --- |
| `Wood` | -1.56〜2.49 | -0.27〜+0.65 | 銃床（後ろ）と handguard（前 1.5〜2.5） |
| `DarkWood` | 1.79〜2.49 | +0.67〜+0.85 | 上部カバー（握る場所ではない） |
| `Black` | -1.60〜2.46 | -0.74〜+0.81 | 弾倉・握り・受け |
| `DarkMetal` / `Metal` | -0.19〜3.82 | +0.15〜+0.86 | 銃身・ガスチューブ |

### 合っているかの確かめ方

見た目で反復すると取り違える。`_verify_grip()` が、適用後の値で握りと handguard が実際に手へ来て
いるかを測り、残差を「角度」と「長さ」に分けて出す。

```
検証: 握り→右手 0.0001 m / handguard→左手 0.0002 m
検証: 銃の 握り→handguard 0.3648 m / 両手 0.3649 m（差 -0.0001 m）  角度差 0.04 度
検証: BoneAttachment の拡縮 (1.15, 1.15, 1.15)
```

角度差が残れば向き、長さの差が残れば倍率か拡縮の取りこぼし。1.15 倍の拡縮はこの分解で見つけた。
クリップごとの両手の位置も出せる（待機 0.385 m / 歩き 0.360 m / 走り 0.373 m / 発砲 0.386 m、
向きの差は 6 度以内）。差が小さいので、待機で合わせれば他のクリップでも保つ。

確認は `godot --path . tools/capture_rifle_grip.tscn`（描画が要るのでヘッドレス不可）。
`docs/img/qc_rifle_grip_*.png` に、斜め・正面・真横・発砲・ゲームと同じ真横（左右）・銃口炎を
書き出す。孤立した確認用の画だけで判断しない。ゲームと同じ真横の画で見るまで、左手が銃を握って
いないことに気づけなかった。

### 銃口と狙い

銃口は武器モデルの先端に追従させる（`GunBoss._update_muzzle_position` /
`PlayerWeapon._update_muzzle_position`、測り方は `actors/shared/muzzle_tip.gd`）。
`gun_muzzle_height`（1.05）は狙う高さであって銃口の位置ではない。本体の原点からの高さなので、
狙い点のワールド高さは `ボスの y + gun_muzzle_height` になる。ボスは `y = 0.2` に立つので、ここへ
銃口の高さ（1.59）を入れると狙い点が 1.79 m になり、プレイヤーの当たり判定の上端 1.70 m を超えて
当たらなくなる。1.05 なら 1.25 m で胸に入る。確かめ方は `tools/probe_barrel_aim.gd`（実際にレイを
飛ばして命中点を出す）。
