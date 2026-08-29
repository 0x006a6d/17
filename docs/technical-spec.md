# 技術仕様書（ベルトスクロール版）

対象: Godot 4.7 / GDScript / Forward+ レンダラー

本書は実装済みの状態を書いている。数値は各スクリプトの `@export` 既定値で、`.tscn` で上書きしている箇所はそちらを正とする。プレイヤーの操作の一覧は `docs/controls.md` にある。

## 1. ディレクトリ構成

```
res://
├── autoload/
│   ├── game_types.gd         # enum
│   ├── run_state.gd          # 残機・コンティニュー・進行中の面・得点
│   ├── stage_director.gd     # 面・画面ロック・波の進行
│   ├── sfx.gd                # 効果音の再生枠
│   └── bgm.gd                # 面の音楽とフェード
├── actors/
│   ├── player/
│   │   ├── player.tscn / player.gd          # 段移動・回避・被弾・ダウン
│   │   ├── player_melee.gd / combo_tree.gd  # 素手コンボ
│   │   ├── player_action_anim.gd            # 武器・単発アクションのクリップとステート生成
│   │   ├── player_weapon.gd                 # 持ち替え・射撃・リロード
│   │   ├── player_katana_combo.gd           # 刀の3段
│   │   ├── player_action.gd                 # △必殺
│   │   ├── player_gun_fx.gd                 # 銃口炎・弾道・命中光・反動
│   │   ├── player_weapon_grip*.gd           # 指の握り（modifier と数値解法）
│   │   ├── player_score.gd / player_sfx.gd / player_instant_kill.gd
│   │   └── anim/*.res                       # ベイク済み攻撃クリップ
│   ├── enemy/
│   │   ├── enemy.tscn / enemy.gd           # 敵の共通挙動（ナビ無しの段追従）
│   │   ├── npc_animator.gd                 # 敵のクリップ再生
│   │   ├── enemy_attack_profile.gd         # 攻撃1種ぶんの距離・威力・タイミング
│   │   ├── enemy_gun_fx.gd                 # 銃口炎を撃った向きへ回す（PlayerGunFx 派生）
│   │   ├── enemy_left_grip*.gd             # 長物を支える左手
│   │   ├── dummy.tscn / dummy.gd           # テスト用の棒立ちダミー
│   │   ├── roles/
│   │   │   ├── grunt_b.tscn / grunt_c.tscn         # 通常型の見た目違い（Ch28 / Ch06）
│   │   │   ├── grunt_a_black.tscn / grunt_b_pink.tscn / grunt_c_yellow.tscn / rusher_red.tscn
│   │   │   │                                       # 色違い（PaletteSwap）
│   │   │   ├── rusher.gd / rusher.tscn             # 突進型
│   │   │   ├── bruiser.gd / bruiser.tscn           # 中ボス。数値違い
│   │   │   ├── shielder.gd / shielder.tscn         # 4面ボス（GunBoss 派生）
│   │   │   ├── zombie*.tscn                        # 4面の雑魚（クリップと速度だけ差し替え）
│   │   │   ├── zombie_escort.tscn                  # 4面ボスの供回り（Ch30）
│   │   │   ├── final_guard.tscn                    # 5面の増援（Ch18）
│   │   │   └── nike_blank.tscn                     # 5面の増援（ニケの素体）
│   │   └── bosses/                          # 1〜4面の外見・武器差分
│   │       ├── stage_1_boss.tscn / stage_2_boss.tscn
│   │       ├── stage_3_boss.tscn / gun_boss.gd
│   │       └── stage_4_boss.tscn
│   ├── hostage/
│   │   └── hostage.tscn / hostage.gd       # 4面の「次の身体」。座る／盾にされるの2状態だけ
│   ├── boss/
│   │   ├── nike.tscn / nike.gd             # 5面のニケ。プレイヤーと同じ AnimationTree・コンボツリー
│   │   └── nike_skin.gd                    # ヘアピン非表示・シャツ赤のランタイム上書き
│   └── shared/                             # health / hitbox / model_blink / weapon_holder / weapon_loadout 等
├── levels/
│   ├── belt_stage.gd                       # 面の共通スクリプト
│   ├── belt_camera.gd                      # 側面固定カメラ
│   ├── lock_point.gd / wave_spec.gd        # 画面ロック地点と波の指定
│   ├── boss_trigger.gd                     # ボス開始地点
│   ├── belt_test.tscn                      # テスト用ベルト
│   └── stage_1.tscn … stage_5.tscn
├── ui/
│   ├── title_screen.tscn / title_screen.gd # タイトル
│   ├── hud.tscn / hud.gd                   # HP・残機・武器・残弾・ボスバー・GO・題名・得点
│   ├── text_card.tscn / text_card.gd       # OP / 幕間 / 開示 / ED / コンティニュー共用
│   ├── result_panel.tscn / result_panel.gd # 得点と X 投稿
│   ├── speaker_profile.gd / enter_prompt.gd
│   └── input_log.gd                        # デバッグ用に残す
├── fx/                                     # hit_stop / camera_shake / damage_feedback_3d / impact_slash_3d
│                                           # ＋ attack_cry_3d / dropkick_vfx_3d / katana_swing_3d /
│                                           #   kick_trail_ribbon_3d / directional_blood_spray_3d /
│                                           #   electrocution_lightning_3d / procedural_glow
├── assets/
│   ├── vrm/nikechan_player.vrm
│   ├── characters/mixamo_ch*.fbx
│   ├── motions/mixamo_*.fbx
│   ├── weapons/{pistol,katana,rifle}.glb
│   ├── backgrounds/stage*_{far,mid,ground}.png
│   ├── bgm/stage*.{ogg,mp3} / sfx/*.wav / voice/*.wav
│   ├── fonts/ShipporiMinchoB1-ExtraBold.ttf
│   └── ui/title_screen_seventeen.png ほか
└── tools/                                  # 計測・テスト
```

## 2. 物理レイヤー

物理レイヤーの割り当ては次のとおり。

|#|名前|用途|
|---|---|---|
|1|`world`|床、壁、什器|
|2|`player`|プレイヤー本体|
|3|`enemy`|敵本体|
|4|`hostage`|4面の「次の身体」|
|5|（未使用）|—|
|6|`hitbox`|攻撃判定（`Area3D`）|
|7|`hurtbox`|被弾判定（`Area3D`）|
|8|（未使用）|—|

`Hitbox` は layer=6 / mask=7、`Hurtbox` は layer=7 / mask=6。グループは `player` / `enemy` / `hostage` の3つ。`Hitbox.ignore_groups` はシーン側で指定し、プレイヤーの素手・刀は `["hostage"]`、敵とニケの近接は `["enemy", "hostage"]`。`exempt_body`（この本体だけ除外を無視する）の仕組みは残してあるが、ロックオンが無いので誰も設定しない（4面の身体には誰の攻撃も当たらない）。

## 3. グローバル型定義

`autoload/game_types.gd`

```gdscript
extends Node

enum Faction { PLAYER, ENEMY, HOSTAGE }
enum Stage { STAGE_1, STAGE_2, STAGE_3, STAGE_4, STAGE_5 }
## 得点の計算で使う武器種。PlayerWeapon.WeaponKind と同じ並びだが、autoload から
## プレイヤー側のクラスへ依存しないためここにも置く。
enum ScoreWeapon { UNARMED, GUN, KATANA }
```

`CombatMode` / `Act` / `Ending` は削除済み。

## 3.5 VRM モデル

公式アセットリポジトリ: https://github.com/tegnike/nikechan-assets

|ファイル|用途|
|---|---|
|`vrms/nikechan_v2.vrm`（`assets/vrm/nikechan_player.vrm` として配置）|プレイヤー。5面のニケも同じファイルを使う|
|`vrms/nikechan_v2_outerwear.vrm` / `nikechan_v1.vrm`|使用しない|

導入手順・MToon・SpringBone・BoneMap 接頭辞の扱いは次のとおり。

- `godot-vrm`（V-Sekai）でインポートし、`.tscn` として `Model` に置く。トゥーンシェーダーを自作しない
- Mixamo モーションは `SkeletonProfileHumanoid` へリターゲットする。BoneMap は sanitize 後の接頭辞ごと（`mixamo_bone_map.tres` / `_rig1.tres` / `_rig0.tres`）。対応表は `docs/asset-credits.md`
- 実寸は身長 160cm。コリジョン・Hitbox 位置はこれを基準にする

### ニケ（ボス・人質）の外見

VRM ファイル自体は改変せず、シーン側のスクリプト `actors/boss/nike_skin.gd` でランタイムに上書きする。これで配布物に改変 VRM を含めずに済む。

```gdscript
extends Node
## nikechan_player.vrm のインスタンスに対し、ヘアピンを隠しシャツの色を変える。
@export var model_path: NodePath = ^"../Model"
@export var hairpin_mesh_names: Array[StringName] = []   # 要調査。tools/inspect_vrm_meshes.gd の出力から埋める
@export var shirt_material_names: Array[StringName] = []  # 同上
@export var shirt_color: Color = Color(0.80, 0.10, 0.12)  # 5面は赤。4面（人質）は上書きしない
@export var recolor_shirt: bool = true
```

- ヘアピン: 髪飾りのマテリアル `NikeChanKazari` はヘアピン・シュシュ・イヤリングを兼ねる（`NikeFace` サーフェス3、`Hair_Up_2` サーフェス3）ため、マテリアル単位では消せない。`NikeFace` の該当サーフェスを複製し、重心がバインドポーズの AABB（`hairpin_aabb_min/max`、既定 x 0.03〜0.12 / y 1.395〜1.55 / z 0〜0.12）に入る三角形だけをインデックス配列から除いて作り直す（実測 124 三角形）。頂点配列・ブレンドシェイプ・ボーン重みは触らない。共有メッシュなので `duplicate()` してから差し替える
- シャツ: マテリアル `NikeChanTshirt`（`Fuku` サーフェス1、MToon `ShaderMaterial`）を `duplicate()` し、`_MainTex` / `_ShadeTexture` を白、`_Color` / `_ShadeColor` を `shirt_color` / `shirt_shade_color` に置き換えて `set_surface_override_material()` で当てる。元のマテリアルリソースは触らない
- メッシュ名・マテリアル名・頂点分布はインポート結果に依存するので、`tools/inspect_vrm_meshes.gd`（名前の列挙）と `tools/probe_vrm_kazari.gd`（髪飾りサーフェスの三角形重心の分布）で調べてから `@export` に入れる。名前や座標をコードへ直書きしない
- 4面の人質は `recolor_shirt = false`（ヘアピン除去のみ）、5面のボスは `true`
- 確認は `tools/capture_nike_head.gd`（素 / 人質 / ボスを並べた頭部アップと全身）で行う

### ボイス

台詞は喋らない（ニケと敵の言葉はテキストカードのみ）。被弾とダウンの短い掛け声だけを
`actors/shared/voice_reactions.gd` で鳴らす（素材は自作。詳細は §16.5）。

## 4. RunState（autoload）

唯一のグローバル可変状態。持つのは残機・コンティニュー・進行中の面・撃破数・得点だけで、進行判定は持たない。

```gdscript
extends Node

signal lives_changed(lives: int)
signal continues_changed(continues: int)
signal stage_changed(stage: int)
signal score_changed(score: int)

@export var initial_lives: int = 3
## 残機を減らさず必ず立ち上がる。試遊用の既定値。
@export var infinite_lives: bool = true
@export var initial_continues: int = 3
@export var score_hit_unarmed: int = 100   # 素手1発の基礎点
@export var score_hit_katana: int = 60
@export var score_hit_gun: int = 30
@export var score_combo_multiplier: bool = true
@export var score_defeat_bonus: int = 200
@export var score_death_penalty: int = 500

var lives: int = 3
var continues: int = 3
var current_stage: int = GameTypes.Stage.STAGE_1
var enemies_downed: int = 0       # 表示用。進行判定には使わない
var score: int = 0                # HUD 右上と結果画面で使う

func lose_life() -> bool:         # 残機を1減らし、0 になったら false（コンティニュー待ち）
								  # infinite_lives のときは減らさず常に true
func use_continue() -> bool:      # continues を1減らし lives を初期値へ
func add_hit_score(weapon_kind: int, combo_stage: int = 1) -> void
func add_defeat_score() -> void
func apply_death_penalty() -> void   # 0 未満にはしない
func reset() -> void:             # 得点も 0 へ戻し、score_changed を出す
```

進行判定（波の全滅・面の終了）は `StageDirector` が持ち、`RunState` は `_process()` を持たない。

得点を変える通知は3種類で、入口は `actors/player/player_score.gd` にまとめる（§16.1）。

|通知|出どころ|得点|
|---|---|---|
|命中|`Hitbox.hit_landed`（素手・刀）／`PlayerWeapon.shot_hit`（銃）|`add_hit_score()`|
|敵の撃破|`Enemy._on_downed()` / `Nike._on_downed()`（`enemies_downed` と同じ場所）|`add_defeat_score()`|
|プレイヤーの死亡|`Health.downed`（残機の消費とは独立。無限残機でも減点する）|`apply_death_penalty()`|

`weapon_kind` は `GameTypes.ScoreWeapon`（autoload からプレイヤー側のクラスへ依存しないため、
`PlayerWeapon.WeaponKind` と同じ並びで別に持つ）。

## 5. StageDirector（autoload）

面・画面ロック・波の進行。面内の具体的な配置は各 `levels/stage_N.tscn` が持ち、`StageDirector` は状態遷移と通知だけを担う。

```gdscript
extends Node

enum Phase { CARD, PLAY, LOCKED, BOSS, CLEARED }

signal phase_changed(phase: int)
signal lock_started(lock_index: int)
signal lock_cleared(lock_index: int)
signal boss_started(boss: Node3D)
signal boss_defeated()
signal stage_cleared(stage: int)
signal stage_title_shown(title: String)   # 面の題名（HUD が画面上中央に出す。§13-7）

var phase: int = Phase.CARD
```

|遷移|条件|
|---|---|
|CARD → PLAY|テキストカードが `ui_accept` で閉じた|
|PLAY → LOCKED|プレイヤーが `LockPoint` を通過した（`LockPoint.reached`）|
|LOCKED → PLAY|その `LockPoint` が出した波の敵が全員 DOWNED|
|PLAY → BOSS|プレイヤーが面末尾の `BossTrigger` を通過した|
|BOSS → CLEARED|ボスが DOWNED|
|CLEARED → 次の面の CARD|カードを表示し、`get_tree().change_scene_to_file()` で次の面へ|

5面の CLEARED はカードを表示して終わる（ED）。次の面のシーンパスは各面の `BeltStage.next_stage`
が `@export` で持ち、空なら結果画面へ進む。

## 6. プレイヤー

`actors/player/player.tscn`

```
Player (CharacterBody3D, group=player, layer=2 / mask=1)
├── Model (VRM nikechan_player.vrm)
│   ├── MeleeHitbox (Area3D)        # 素手。Call Method Track で開閉
│   └── KatanaHitbox (Area3D)       # 刀。段ごとに半径と位置を組み替える
├── PlayerMelee (Node)              # コンボツリーと AnimationTree の駆動
├── PlayerActionAnim (Node)         # 武器・単発アクションのクリップとステート生成
├── WeaponHolder / PlayerWeaponGrip # 手ボーンへの装着と指の握り
├── PlayerKatanaCombo (Node)        # 刀の3段
├── PlayerWeapon (Node)             # 持ち替え・射撃・リロード
├── PlayerAction (Node)             # △必殺
├── PlayerScore / PlayerInstantKill / PlayerSfx
├── PlayerGunFx / PlayerKatanaSwing3D / DropkickVfx3D / AttackCry3D / ImpactSlash3D
├── CollisionShape3D                # カプセル r=0.35 / h=1.6
├── Health (max_hp 30000) / Hurtbox
├── DamageFeedback3D / RecoveryBlink / Voice
└── Camera3D は持たない（面側の BeltCamera が追従する。§6.1）
```

`AnimationTree` / `AnimationPlayer` は VRM の `Model` 配下に `PlayerMelee` がコードで組み立てる。
カメラ・ロックオン・銃口点のノードは持たない。

### 6.1 段移動とカメラ

- 入力 `move_left` / `move_right` は X、`move_forward` / `move_back` は Z（奥行き。`move_forward` = 奥 = -Z）
- 移動は `move_and_slide()`。移動速度 4.5 m/s、加速 `accel` 10、減速 `decel` 14、攻撃中のブレーキ `attack_brake` 30（いずれも m/s²）。技ごとの踏み込み（`*_lunge_speed`）は向いている X 方向へ出す。奥行きは `depth_speed_ratio` 0.7 倍で遅い
- 奥行きは `belt_z_min` / `belt_z_max`（`@export`、既定 -1.5 / 1.5）で clamp する。壁コリジョンではなく数値で止める（面ごとに `BeltStage` が上書きする）
- 向きは ±X の2方向。`facing: int`（+1 / -1）を持ち、X 入力の符号で切り替える。`Model` の Y 回転を 90° / -90° に `rotation_speed` で補間する（VRM の前方は `Model` の +Z）。Z 入力だけでは向きを変えない
- カメラは面側の `BeltCamera`（`Camera3D` ＋ `levels/belt_camera.gd`）。プレイヤーの X に `follow_speed` 8.0 で追従し、Z と Y は固定。`LOCKED` 中は `lock_x` で止める。俯角 `pitch_deg` 12°、FOV `fov_deg` 35°、距離 `distance` 8.5m、注視高さ `look_height` 1.0m。`CameraShake` はこのカメラの子に置く
- 画面端: カメラの X を `BeltStage.x_min` / `x_max` と `LOCKED` 時の `lock_x` で clamp し、プレイヤーの X はカメラ視錐台の左右端の内側（`screen_margin`）で止める。`LOCKED` 中は左右どちらにも抜けられない

### 6.2 戦闘

素手コンボは `combo_tree.gd` の `ROOTS` / `NODES` が構造を持ち、`player_melee.gd` が
AnimationTree を駆動する。ルートは6本・技は6種類で、全ルートと数値は `docs/controls.md` §3。

- 技ごとの抜け割合（`*_out_ratio`）、踏み込み初速（`*_lunge_speed`）、`press_debounce_frames` 4、
  各 xfade（開始 0.08 / 段間 0.05 / 復帰 0.20 秒）、段後の猶予 `combo_grace_time` 0.40 秒
- 判定の開閉は melee クリップの Call Method Track が `_enable_hitbox` / `_disable_hitbox` を叩く。
  コード側でタイマーは持たない
- `hit_landed` を起点にヒットストップ（0.09 秒・スケール 0.15）とカメラシェイク（0.6）を出す
- 命中には奥行き条件が付く（§7.2）

### 6.3 回復

`interact` 長押しで `dance` ステートへ入り、`dance_heal_per_second`（既定 1000／秒）で回復する。
停止していないと始まらず、移動入力・攻撃入力・被弾・ダウンで中断する。

### 6.4 被弾・ダウン・残機

被弾すると `hurt_knockback_decay` 0.28 秒の入力ロックとノックバック、上半身レイヤーの被弾
リアクション（0.60 秒）、カメラシェイク（0.8）が入る。HP が尽きたときは次のように進む。

- ダウンクリップ（Standing Death Backward 01）を `down_fall_time` 1.6 秒で再生し、終端で保持する。
  倒れている間は無敵で、失うのは時間だけ
- `down_duration` 3.0 秒の経過後に `RunState.lose_life()` を呼ぶ。残機が残っていれば Kip Up で
  `stand_up_time` 1.70 秒かけて立ち上がり、立ち上がりきった時点で HP を全快させる
  （立ち上がり中に全快させると、無敵が切れて入力が戻らない一方的な被弾窓ができる）
- 残機が尽きると `player_out_of_lives` を送り、`BeltStage` がテキストカードで
  「CONTINUE?　残り N」を出す。`ui_accept` で `RunState.use_continue()` → 現在の面を再読込、
  何もしなければ `continue_timeout` 10 秒でゲームオーバー（結果画面 → タイトル）
- `RunState.infinite_lives` は既定 `true`（試遊用）。この間は残機が減らず必ず立ち上がるので、
  コンティニューの経路には入らない。HUD の残機欄は「残機 ×無限」と出る

### 6.5 回避と必殺

素手コンボ以外の全身技は2つある。数値は `docs/controls.md` §5・§6。

|アクション|入力|置き場|
|---|---|---|
|回避（バックフリップ）|`dodge`|`player.gd`。移動と無敵（`Hurtbox.monitorable` を切る）が本体側にあるため|
|必殺（回転飛び蹴り）|`special`|`actors/player/player_action.gd`。対象選択は敵グループへの範囲問い合わせ、ダメージは `Hurtbox.receive_area_hit()`|

どちらもクリップの再生は `PlayerActionAnim` が持つ単発ステート（§14.5）で、`request_action()`
で開始する。掴み・投げ・ジャンプ・メガクラッシュは持たない。

## 7. 共有部品

### 7.1 Health

`max_hp` / `stagger_threshold` / `take_hit()` / `heal()` / `revive()` / `hp_changed` / `staggered` /
`downed` を持つ。`spend()` は必殺の自傷用で、被弾ではないので `staggered` を出さない
（`take_hit` で代用すると掛け声が「やられた」側で鳴る）。実際に引く量は `DamageRoll.roll()` が
端数のある整数へ丸める。`finish_hits` / `take_finish_hit()` / `finished` は追い打ちが無いので
呼ばれないが、API は残してある。

### 7.2 Hitbox / Hurtbox

`Hitbox._try_hit()` の判定順は次のとおり。

1. 陣営フィルタ（`ignore_groups` / `exempt_body`）と二重ヒット防止
2. 奥行き: `abs(source_body.global_position.z - target_body.global_position.z) <= depth_tolerance`（`@export`、既定 0.6m）でなければ当たらない。`hit_landed` も送らない（偽の手応えを返さない）
3. `blocks_hit_from(attacker_position)` の問い合わせ（ガードと盾）。弾かれたときは `hit_blocked` だけを送る
4. `Hurtbox.receive_hit()`

この規則は敵の近接にも同じ `Hitbox` を使うので自動で効く。銃撃は共有 `HitscanGun` から
`Hurtbox.receive_shot()` へ渡し、プレイヤーと3面ボスで同じ実ダメージ経路を使う。

### 7.3 StateMachine / NpcAnimator / ModelTint / RootMotion / ToonSkin

規約は次のとおり。静止ポーズは1フレームのループクリップで作る。Hips の水平移動は
`RootMotion.lock_horizontal()` で潰す。被弾フラッシュは `ModelTint` の `material_overlay` だけを
触る。消滅前点滅（`ModelBlink`）は同じメッシュ一覧の `transparency` を使い、色のチャンネルとは
分離する。

## 8. 敵（Enemy）

`actors/enemy/enemy.gd` + `enemy.tscn`。Health / Hurtbox / MeleeHitbox / StateMachine / NpcAnimator を持ち、見た目は `model_scene` に Mixamo キャラの FBX を差し込んで作る。役割別シーンは全て `enemy.tscn` を継承し、数値と見た目だけを上書きする。

### 8.1 ステート

```gdscript
enum State { SPAWN, APPROACH, ATTACK, STAGGERED, GUARD, DOWNED }
```

知覚（視野・遮蔽）・巡回・`NavigationAgent3D` は持たない。ベルトスクロールの敵は常にプレイヤーを知っているので、知覚は要らない。役割固有ステートは `DOWNED + 1` から各役割スクリプトが定義する。

|ステート|挙動|
|---|---|
|SPAWN|画面外（`spawn_side` の左右どちらか）に出現し、`spawn_walk_in` 秒だけ画面内へ歩く。無敵|
|APPROACH|まずプレイヤーと Z を合わせ（`depth_align_speed`）、次に X を `attack_range` まで詰める。`approach_jitter` で時々 Z をずらして並ばせない。複数体が同じ側に固まらないよう、偶数番目は反対側へ回り込む（`flank_ratio`）|
|ATTACK|予備動作 → 判定 → 硬直 → クールダウン（`attack_telegraph` 0.45 / `attack_active` 0.18 / `attack_recovery` 0.35 / `attack_cooldown` 0.8 秒。実際の値は `attack_profiles` が距離で選ぶ）|
|STAGGERED / GUARD|のけぞり耐性（`poise` 2800・回復 2000／秒）・ガード（`guard_arc_deg` 140°・`guard_chance` 0.4）・反撃（2回受けたら 0.8 で反撃）。ガードの扇形は X の向きで判定する。プレイヤーが段をずらして背後へ出れば扇形の外になる。`staggers = false` の敵（4面・5面のゾンビ）は STAGGERED へ落とさず、軽いのけぞりもノックバックも乗せない（検証: `tools/test_zombie_poise.gd`）|
|DOWNED|倒れ込みのクリップを終端で保持する。`defeated` を送り、`despawn_delay` 4.0 秒後に消える（消える前に `ModelBlink` で点滅する）|

DOWNED へ入るときは `_stop_horizontal_immediate()` に加えてノックバックの残り
（`_knockback_vel` / `_knockback_timer`）も消す。理由は次のとおり。
`Hurtbox.receive_hit()` は「ノックバック → ダメージ」の順で流すため、撃破の一撃では
ダウン確定の時点で受けたばかりのノックバックが残っている。`_physics_process()` の
ノックバックは全ステートに優先して `velocity` を上書きする一方、DOWNED は物理更新を持たず
`velocity` を戻す側がいないので、倒れたまま `move_and_slide()` に運ばれ続ける。さらに減衰は
`knockback_speed / knockback_decay`（12 m/s²）固定で、初速は最大 `knockback_speed` の 2 倍
（6 m/s）まで出るため、`knockback_decay` を過ぎても速度が残り、消えるまで等速で下がっていく。
実測（`tools/test_enemy_down_slide.tscn`、ダウン後3.0秒の本体 x の移動）: 修正前は
`Hitbox.knockback` 3.0 で 0.150m、6.0 で 2.200m、10.0 で 9.400m。修正後はいずれも 0.000m。
5面ニケはプレイヤー派生で `_downed` 分岐が `decel` で減速するうえ `_hurt_timer` も 0 にするため
この経路には乗らない（同条件で 3 強度とも移動 -0.332m、0.5秒以内に静止。向きも接近方向）。

### 8.2 役割

|役割|スクリプト|差分|
|---|---|---|
|通常|`enemy.gd` そのまま|Ch01 / Ch06 / Ch28|
|突進（rusher）|`roles/rusher.gd`（旧 erratic。客を撃つ処理を削除）|距離があるとき `rush_speed` で直線突進し、接触で `rush_damage`。突進後は長めの硬直。Ch08|
|色違い（2面以降）|`actors/shared/palette_swap.gd`|`ToonSkin` が張った MToon の上書きを複製して色だけ差し替える。服が MeshInstance3D で分かれているキャラ（Ch01_Shirt / Ch28_Hoody・Ch28_Pants / Ch08_Pants）は名前で指定。Ch06 は体と服が1メッシュなので、三角形の重心 Y と UV のテクセルの暗さで上半身の服だけを別サーフェスへ切り出す（切り出したメッシュは静的キャッシュで共有）。元が明るい服は掛け算（皺が残る）、元が暗い服はテクスチャを白にして単色|
|ゾンビ（4面の雑魚）|専用スクリプト無し。`roles/zombie*.tscn` がクリップと速度を上書き|見た目は通常と同じ Ch01 / Ch28 / Ch06。待機 `mixamo_zombie_idle`、歩き `mixamo_zombie_walk`、攻撃 `mixamo_zombie_attack`。`chase_speed` 1.05、`depth_align_speed` 1.0、再生倍率上限 3.0。ボス戦に加わる個体だけ Ch30（`roles/zombie_escort.tscn`）|
|5面の増援|`roles/final_guard.tscn` / `roles/nike_blank.tscn`|前者は Ch18（黒ずくめの警備）で、取得ファイルからは見た目だけを使う。後者はニケの素体で、VRM に `NikeSkin`（ヘアピン切り）と `BlankSkin`（全サーフェス白）を掛け、`staggers = false` で怯まない。ゾンビ状態は4面だけなので、どちらも待機・歩き・攻撃は通常型のまま|
|1面ボス（bruiser）|`roles/bruiser.gd`|通常と同じ挙動で `max_hp` ×3、`poise` ×2、`Model.scale` 1.15、`attack_damage` ×1.5。ch35（マスクマン）|
|2面ボス（bruiser＋刀）|`roles/bruiser.gd` ＋ `WeaponLoadout`|swat（SWAT）。`Model.scale` は 1.0。日本刀初段相当の単発斬りで、`guard_chance` 0.75・`guard_arc_deg` 160・`counter_chance` 0.9 と受けが固い|
|3面ボス（gun boss）|`bosses/gun_boss.gd`|ch15（GUNNER）。共通ステートマシンへ射撃距離維持ステートを1つ追加し、共有 `HitscanGun` で撃つ。ボス戦に雑魚は出さない（供回り・増援ともに無し）|
|4面ボス（shielder）|`roles/shielder.gd`（`bosses/gun_boss.gd` 派生）|ch16_boss（マッドサイエンティスト）。盾解除後は主人公と同じ拳銃で距離を取って撃つ。§8.3|

雑魚用の `gunner.gd` と投擲型は追加しない。`HitscanGun` は3面ボス専用AIからも共有する。

### 8.2.1 画面端（敵）

プレイヤーは `screen_margin` ぶん内側で `BeltCamera.left_limit()` / `right_limit()` に clamp されるが、
敵は clamp されていなかった。3面ボスのように後退する敵は画面外へ抜け、プレイヤーが画面端で
止まるため追えず、倒せなくなる。`Enemy` にもプレイヤーと同じ clamp を入れる。

- 出現直後は画面外に居るので、一度画面内に入るまでは clamp しない（`_entered_screen`）
- 「画面内に入った」は**余白を含まない可視範囲**で判定する。余白の内側で判定すると、距離を
  取る敵（3面ボスは `gun_preferred_distance` 4.5m を保つ）はそこまで来ないことがあり、判定が
  立たないまま画面外へ後退できてしまう。実測では 2.56m はみ出したまま戻らなかった
  （検証: `tools/test_boss_offscreen.gd`）
- 閉じ込める線は、入った直後は可視範囲そのもので、そこから `screen_margin` ぶん内側へ
  `screen_margin_ramp`（既定 0.5 秒）かけて寄せる。最初から内側の線で閉じ込めると、可視範囲へ
  入った瞬間に最大 `screen_margin` ぶん引き戻されて位置が飛ぶ
- `DOWNED` は対象外。倒れた個体をカメラが押して滑らせない
- 余白は `Enemy.screen_margin`（既定 0.6、プレイヤーと同値）

### 8.3 4面ボス: 身体を盾にする

`Shielder`（`GunBoss` 派生）の `SHIELD` ステートが `Hostage`（§9）を正面に保持する。

- 面開始時点で既に `Hostage.enter_shielded(self)` 済みの状態で出す（接近して掴む手順を踏まない。`grab_on_ready = true`）
- `shield_offset` 0.7m / `shield_face_speed` 1.5 / `shield_arc_deg` 120° / `shield_break_hits` 3 回 / `regrab_cooldown` 6.0 秒。`blocks_hit_from()` は基底のガードと OR
- 側面・背面から `shield_break_hits` 回当てると身体を放して APPROACH へ落ちる。放した後は `regrab_cooldown` の経過で再度掴みに行く。身体は放されている間その場に座る（§9）
- 盾を構えている間も撃つ。その場から動かず `shield_fire_interval`（既定 2.0 秒）間隔の牽制で、
  解除後の `gun_fire_interval`（0.9 秒）より遅い。構えた瞬間には撃たず、SHIELD へ入るときに
  1 周期ぶん置く。正面は盾で弾かれるので、プレイヤーは撃たれながら側面へ回り込むことになる。
  射線の判定・狙いの条件は `GunBoss._try_fire()` を SHIELD からも呼んで共有する
  （検証: `tools/test_shielder_gun.gd`）
- 盾越しの攻撃はボスにも身体にも通らない。身体は Hurtbox を持たない（§9）
- 実体は `stage_4_boss.tscn` の ch16_boss。盾解除後は近接せず、3面ボスと同じ `GUN_COMBAT`
  （`bosses/gun_boss.gd`）で距離を取って撃つ。`Shielder` は `GunBoss` を継承し、`SHIELD` は
  `GUN_COMBAT + 1` に置く。掴み直せる状態（`regrab_cooldown` 明け・人質が着席中）になったら
  `GUN_COMBAT` を抜けて `APPROACH` へ戻り、人質へ寄る
- 銃は主人公と同じ `assets/weapons/pistol.glb`。握りの数値（`grip_offset` / `grip_rotation` /
  `grip_scale` / 軸・半径）と `grip_profile = Pistol` は `player_weapon.gd` の拳銃と同じ値、
  1発 4500・射程 22m・単発（`burst_count = 1`）・`gun_fire_interval` 0.9 秒、`fire_sound` は
  プレイヤーと同じ `gun_shot`。保つ距離は `gun_preferred_distance` 4.5m（`gun_retreat_distance` 3.0m）
  （検証: `tools/test_enemy_boss_loadouts.gd` / `tools/test_shielder.gd`）

### 8.4 波（スポーン）

`levels/lock_point.gd`。`Area3D` で、プレイヤーが入ると `reached` を送り、`waves: Array[WaveSpec]` を順に出す。`WaveSpec` は `Resource` で `enemy_scene` / `count` / `side` / `delay` / `spacing` を持つ。波の全員が DOWNED で次の波、最後の波が終われば `cleared`。同時出現上限は `max_alive`（既定 4）。

## 9. Hostage: 4面で盾にされる身体

`actors/hostage/hostage.gd`。

- `Model` は `nikechan_player.vrm` のインスタンス＋`nike_skin.gd`（`recolor_shirt = false`）
- ステートは `SEATED` / `SHIELDED` の2つ。`SEATED` は床に座る静止ポーズ（1フレームループ）、`SHIELDED` は保持者の正面 `shield_offset` に立つ
- Hurtbox を持たない（誰の攻撃も当たらない）。`Health` も持たない
- 逃走・伏せ・被弾・ダウン・`set_melee_targetable()` は持たない
- 4面ボスが DOWNED したら `SEATED` に戻る。`BeltStage.reveal_hostage_stands` は `false` なので
  立ち上がらせず、崩れたまま開示（§11）へ入る

## 10. 最終ボス: ニケ（5面）

`actors/boss/nike.tscn` / `nike.gd`

- `nike.gd` は `player.gd` を継承する。`Model`（VRM）＋`PlayerMelee`＋`MeleeHitbox`＋`Health`
  （`max_hp` 60000）＋`Hurtbox` は `player.tscn` と同じ構成で、差し替えるのは入力の読み取りだけ
  （`_read_move_input()` / `_accepts_player_input()` / `_interact_held()` を上書きし、
  攻撃は `PlayerMelee.attack()` / `kick()` を直接呼ぶ）
- `nike_skin.gd`（`recolor_shirt = true`、赤）。武器は持たない（素手のみ）
- `Hitbox.ignore_groups = ["enemy", "hostage"]`、グループは `enemy`（HUD・`StageDirector` の判定を共通化するため）
- `uses_lives = false`。倒れたら立ち上がらず `defeated` を送り、`despawn_delay` 4.0 秒後に消える
- AI（`@export` で調整）

|状況|行動|
|---|---|
|X 距離 > `engage_range` 1.35m|Z を `depth_align_threshold` 0.25m まで合わせながら接近|
|X 距離 < `too_close_range` 0.55m|半歩下がる|
|X 距離 ≤ 1.35m かつ 奥行き差 ≤ `ai_depth_tolerance` 0.42m|`COMBOS`（5系統）から1つを選び、`stage_started` に合わせて次のボタンを押す。コンボ後は 0.5〜1.3 秒のクールダウン|
|`guard_window` 0.7 秒に2回被弾|`guard_chance` 0.5 でガード（0.9 秒）。向いている側からの近接だけを弾く。再使用待ち 2.0 秒|
|プレイヤーが `dance` 中|クールダウンを待たずに詰める|
|HP が 50% / 30% / 15% を切った（各1回）|`adds_requested(2)` を出し、`retreat_time` 1.6 秒だけ距離を取る。実体化は `BeltStage` が `adds_scenes` から行う|

`COMBOS` は `PPP` / `KKK` / `PKPP` / `PKKP` / `PPKPK` の5系統。素手コンボツリーの全6ルートのうち、
最長の `KPPPKPK` だけ使わない。

## 11. テキストカード（OP / 幕間 / 開示 / ED）

`ui/text_card.tscn` / `text_card.gd`、話者定義 `ui/speaker_profile.gd`。1シーンを `@export` の内容で使い回す。

```gdscript
@export var lines: Array[String] = []
@export var speakers: Array[SpeakerProfile] = []   # 台本の名前で引く（AIニケ / ニケ / ミカゼ）
@export var portrait: Texture2D           # 地の文の左に出す立ち絵。無ければ非表示
@export var monospace_green: bool = false # 地の文を受信記録体裁にする
@export var auto_close_after: float = 0.0 # 0 なら ui_accept 待ち
signal closed()
```

- 表示中は `SceneTree.paused = true`、カードは `PROCESS_MODE_ALWAYS`。プレイヤーの
  `AnimationTree` も `PROCESS_MODE_ALWAYS` にして、カードの裏で待機モーションを止めない
  （止めると VRM の素の姿勢＝T ポーズや、髪が舞い上がったままで固まる）
- タイプ表示は経過時間から `visible_characters` を算出する
- 文言は `levels/stage_N.tscn` の `BeltStage` が `@export` で持ち、コードに直書きしない。台本（`nike_story_design.md` §3）の行をそのまま入れる
- 1行が1枚のカード。空行と `---` は台本上の区切りで、画面には出ない
- 送りは押し下がり1回につき1段（文字送りの途中なら全文表示、出し終わっていれば次の行）。
  入力はイベントとポーリングの両方で受けるので、押し下がりの検出は毎フレーム回してロックとは
  切り離す（短絡させると1回の押しで2段進む）
- Esc / △ で残りを飛ばして閉じる。案内はカードの左下に常に出す
- **話者と改ページ**: `名前「本文」` の行は話者付き。名前が `speakers` に無ければ地の文。改ページは1行ごと（上の「1行が1枚のカード」）。本文から名前と「」は外す
- **通話画面の体裁**: 話者付きページは、`SpeakerProfile.side` の側に話者タイル（`PanelContainer`。立ち絵の顔を `portrait_region` で正方形に切り出し、円形シェーダで表示。名前ラベルと枠線は話者の色）、反対側に文章。AIニケ=左、ニケ・ミカゼ=右。タイル幅は 150px（パネル 1040×208px）。地の文はタイル無し。文章は地の文も含めて左揃え
- `ui_accept`: 表示途中なら全文、出し終わっていれば次のページ、最後なら閉じる
- 立ち絵は公式サイトの三面図 3 枚（`assets/portraits/*_trihedral.png`、`tools/fetch_assets.sh` で取得。リポジトリに含めない）。無ければタイルの顔だけ空になる
- 開示（4面ボス撃破後）は、身体（`Hostage`）を崩れたまま（`reveal_hostage_stands = false`）→ ニケの独白カード（複数ページ）→ 画面フラッシュ → 5面へ。ニケの `nike_skin.recolor_shirt` は 4面 `false`、5面 `true`
- 文字は `project.godot` の `gui/theme/custom_font` で Shippori Mincho B1 ExtraBold に統一する
  （`assets/fonts/`。HUD・カード・結果画面が同じ字面になる）
- 本文の `RichTextLabel` は `visible_characters_behavior = VC_CHARS_AFTER_SHAPING`。既定の
  BEFORE_SHAPING は表示済みの文字だけで行を組むため、行の高さがその時点で使っている
  フォントの最大 ascent で決まる。最後に別フォントへ落ちる文字（全角「？」など）が出た
  瞬間に行が下へずれる（1面冒頭「行ける？」で実測 5px）
- 見た目の確認は `tools/capture_text_card.gd`（全面の全ページを `docs/img/qc_card_*.png` に保存）と
  `tools/capture_card_typing.gd`（同じページを文字数ごとに撮る）、挙動は `tools/test_text_card.gd`、
  文字送り中の描画位置は `tools/test_card_line_height.gd`

## 12. 面（Stage）

`levels/belt_stage.gd` を各 `stage_N.tscn` のルートに付ける。

主な `@export`。

```gdscript
@export var x_min: float = 0.0          # ベルトの X 範囲。カメラ中心はこの内側だけ動く
@export var x_max: float = 60.0
@export var belt_z_min: float = -1.5    # 奥行きの範囲
@export var belt_z_max: float = 1.5
@export var spawn_margin: float = 1.5   # 画面端から外側のどこに敵を出すか
@export_file("*.png") var ground_texture_path: String = ""
@export var ground_tile_size: float = 8.0
@export var stage: int = GameTypes.Stage.STAGE_1
@export_file("*.tscn") var next_stage: String = ""
@export var stage_title: String = ""         # カードを閉じたあと上中央に出す
@export var opening_lines: Array[String] = []  # 冒頭のカード。空ならカード無しで即プレイ
@export var reveal_lines: Array[String] = []   # ボス撃破後のカード（回想・開示・ED）
@export var reveal_delay: float = 1.5
@export var reveal_flash: bool = false         # カードのあと白フラッシュ
@export var reveal_hostage_stands: bool = false
@export var next_stage_delay: float = 4.0
@export var boss_mobs_max_alive: int = 2       # ボス戦に出す雑魚の同時上限
@export var adds_scenes: Array[PackedScene] = []   # 増援を種類ごとに出し分ける
@export var boss_escorts: Array[PackedScene] = []  # ボス戦開始と同時に出す供回り
@export var continue_timeout: float = 10.0
@export var show_result_panel: bool = true
@export var bgm: AudioStream = null
@export var bgm_volume_db: float = 0.0
@export var lock_points: Array[NodePath] = []
@export var boss_trigger_path: NodePath
```

- 床は X 方向に長い `StaticBody3D` の箱。Z は `belt_z_*` で clamp するので壁は要らない。
  `ground_texture_path` の画像を `ground_tile_size` の密度でタイルして貼る
- 背景は `levels/belt_backdrop.gd`。描いた横長の1枚絵を層で立て、カメラの X 追従に対して
  層ごとに `parallax` の割合でずらす。各層は `{texture_path, y_center, height_m, z_depth,
  parallax, tile_width_m}` の Dictionary で面側が持つ。1〜3面は遠景＋中景の2層、4・5面は遠景1層
- `BeltCamera` は面の子。`x_min` / `x_max` と `LOCKED` 時の `lock_x` を `BeltStage` から受け取る

|面|題名|X 範囲|構成|ボス|
|---|---|---:|---|---|
|1|ターミナル・スラム|0〜60m|ロック2回（計10体）|`Ch35` マスクマン|
|2|タイムライン地下鉄|0〜60m|ロック2回（計13体）。色違いを混ぜる|`Swat` SWAT（日本刀）|
|3|Discord湾岸|0〜60m|ロック2回（計17体）|`Ch15` GUNNER（ライフル）|
|4|工場|0〜30m|ゾンビの波1回（計5体）→ 盾持ちのボス。撃破で開示|`Ch16_boss` マッドサイエンティスト（拳銃）|
|5|ポーランドの部屋|0〜20m|雑魚の波は無く、ボスのみ|`nike.tscn` ニケ|

1〜3面はロック地点が X=12m と X=28m、ボストリガーが X=46m。4面はロック X=7m、ボストリガー
X=13m（カメラを X=18m に固定）。5面はボストリガー X=5m（カメラを X=10m に固定）。
3面は第2ロックからボストリガーまで18mの通路を取り、ボスは右側から出る。Ch15 は 3.0m 未満で
後退、4.5m 超で接近するため、出現直後から距離維持戦へ入る。

波の中身（`WaveSpec` の並び。Ch28/Ch06 等は色違いを含む）。

|面|ロック1|ロック2|
|---|---|---|
|1|Ch01×2 → Ch28×3|Ch08×1 → Ch01×2 → Ch06×2|
|2|Ch01×2 → Ch08赤×1 → Ch06×3|Ch28桃×2 → Ch08×2 → Ch01黒×3|
|3|Ch08赤×2 → Ch01×3 → Ch28×3|Ch01黒×3 → Ch08×2 → Ch06黄×4|
|4|ゾンビ Ch01×2 → ゾンビ Ch28桃×2 → ゾンビ Ch06黄×1|—|

ボス戦に加わる雑魚は、4面が供回り2体（`Ch30` のゾンビと通常型のゾンビ）＋ HP30% の増援4体
（ゾンビ3種を順に使い回す）、5面が HP50%/30%/15% の増援2体ずつ（`Ch18` の警備とニケの素体を
交互）。同時に画面へ出るのは `boss_mobs_max_alive` 2体まで。

幕間は各面の `BeltStage.opening_lines` で出す。1面はミカゼの通信4行、2〜4面は1行、5面は無し。
1〜3面の `reveal_lines` は AIニケちゃんの回想、4面は開示（白フラッシュ付き）、5面は ED。
文言の正は `levels/stage_N.tscn` と `nike_story_script.md`。

## 13. HUD

`ui/hud.gd`（縮小）。表示は8点（プレイヤー情報4点＋進行情報2点＋面の題名・得点）のみ。

1. プレイヤー HP: 数値と `ProgressBar`（`Health.hp_changed` を購読）
2. 残機: `RunState.lives_changed` 購読
3. 現在の武器: `PlayerWeapon.weapon_changed` を購読し、銃・日本刀・素手を表示
4. 残弾: 銃装備中だけ現在/最大弾数を表示。空撃ちは赤点滅、リロード中は専用文言へ切り替え
5. ボスバー: `StageDirector.boss_started(boss)` で表示し、ボスの `Health.hp_changed` を購読。名前は `display_name()`。1面「マスクマン」、2面「SWAT」、3面「GUNNER」、4面「マッドサイエンティスト」、5面「ニケ」
6. GO 表示: `StageDirector.lock_cleared` で画面右端に「GO →」を 2 秒点滅
7. 面の題名: `StageDirector.stage_title_shown(title)` で画面上中央に出す。`BeltStage.stage_title` を
   カードが閉じた時点（カードの無い面は `_ready`）で送り、`stage_title_duration`（既定 3.5 秒）の
   のち `stage_title_fade` でフェードして消す。ボスバーと同じ位置なので `boss_started` で即座に隠す
8. 得点: `RunState.score_changed` を購読して画面右上に出す

削除: 犯人残数・客生存数・ロックオンマーカー・相手の HP ゲージ（ボスバーに置き換え）。`input_log.gd` はデバッグ用に残すが、`@export var debug_visible: bool = false` で既定は非表示。

## 14. 手応え（fx）

`hit_stop.gd`（`ignore_time_scale = true` 必須）、`camera_shake.gd`、`damage_feedback_3d.gd`、`impact_slash_3d.gd`。`CameraShake` は `BeltCamera` の子に置く。

## 14.5 武器（装着と技）

武器は手ボーンに `BoneAttachment3D` で付け、プレイヤー・敵で同じ仕組みを使う。プレイヤーの VRM も敵の Mixamo も `SkeletonProfileHumanoid`（`GeneralSkeleton`）へ
リターゲット済みで、手ボーン名は **`RightHand` / `LeftHand`** で共通。

### 装着

- `actors/shared/weapon_holder.gd`: 対象の `Skeleton3D` を探し、`RightHand` に
  `BoneAttachment3D` を作って武器の glb インスタンスを子に付ける。装備の切り替えは
  `equip(scene, grip_offset, grip_rotation_deg, grip_scale: Vector3)` で子を差し替える。武器ごとに
  手のなかの位置・回転・スケールの
  オフセットを `@export`（`grip_offset` / `grip_rotation` / `grip_scale`）で持つ（モデルごとに
  原点・スケールが違うため）
- `actors/shared/weapon_loadout.gd`: 武器シーン、握り値、モデル座標の握り軸と半径を
  `WeaponHolder` と指modifierへ渡す。親の `_ready()` でモデルを差し込む敵に合わせて装備を
  deferred実行し、プレイヤーと同じ `PlayerWeaponGrip` の15本指ソルバーを使う
- 使用する武器モデル: `assets/weapons/{pistol,katana}.glb`（ともに CC0。
  `assets/weapons/SOURCES.md`）。`grenade.glb` は取得済み資産として残すが、実行時参照は持たない

### 技

|武器|判定|Mixamo クリップ|
|---|---|---|
|銃|`actors/shared/hitscan_gun.gd` が正面 ±X へ水平にレイを飛ばす。1発 4500・射程 22m・連射 0.28 秒・弾数有限|`Shooting`（構えと発砲に分けて使う）/ `Pistol Walk`|
|日本刀|素手とは別の `KatanaHitbox`（球）を段ごとに組み替える近接。3段で 4000 / 5000 / 7000|`Sword Slash` / `Melee Horizontal` / `Katana 360` / `Sword Idle`|

- 射線は ±X 固定で、上下に狙う操作は無い
- 弾数は `RunState` ではなく武器を持つキャラクターの状態として持つ。プレイヤーの残弾は初回だけ
  30発で初期化し、持ち替えでは補充しない。`reload` で1.3秒のリロードを開始し、その間は射撃不可、
  完了時に30発へ戻す
- プレイヤーは素手で始まり、`switch_weapon` で 素手 → 日本刀 → 銃 → 素手 を循環する。素手では
  `WeaponHolder` を空にし、`fire` は何もしない。`attack` / `kick` の素手コンボは武器を持っていても
  そのまま出る
- 日本刀と銃は命中1発ごとに確率で一撃即死する（`actors/player/player_instant_kill.gd`、
  既定は刀 15%・銃 10%）。銃のそれはヘッドショットの扱いだが、射線が水平固定で敵の当たり判定も
  体ひとつなので、頭を狙う操作は無く、当たりどころの当たり外れを確率で表している。
  ボスと4面では起きない。残り HP ぶんのダメージを致死として通すだけで、撃破の加点と死亡演出は
  通常の経路に乗る。判定は `KatanaHitbox.hit_landed` と `PlayerWeapon.shot_hit` の購読で、
  ダメージ計算には触らない（検証: `tools/test_instant_kill.gd`）
- ボスは `adds_hp_ratios`（残り HP の割合）を切るたびに `adds_requested(count)` を出す。面側の
  `belt_stage.gd` が `adds_scenes` から順に出す。4面ボス 30% で4体、
  5面のニケ 50%/30%/15% で2体ずつ。3面ボスは `adds_hp_ratios` を空にして呼ばない
  （検証: `tools/test_boss_adds.gd`）
- ボス戦に出る雑魚は供回りも増援も `boss_mobs_max_alive`（既定2体）までしか画面に出さず、
  超えた分は待たせて、出ている雑魚が倒れた順に出す
- 面に置いてあるボス（4面の盾持ち）は `BossTrigger` に入るまで `set_physics_process(false)` で
  止める。止めないとロック地点の戦いへ歩いて割り込み、ボス戦の開始前に倒せてしまう
  （検証: `tools/test_boss_mobs.gd`）
- ダメージと回復は `DamageRoll.roll()` を通して端数のある整数にする。上へ 1〜12% だけ振るのは、
  主人公の攻撃を4桁に保つため。数字は HP の差分から作るので、表示と実際に減る量は必ず一致する。
  小数点は出さない（検証: `tools/test_damage_roll.gd`）
- ダメージ・HP・のけぞり耐性は「主人公の攻撃を常に4桁にする」ために、全体で桁を 100 倍に
  取ってある。力関係は倍率で決まるので、桁を落としても釣り合いは変わらない。得点
  （`RunState` の配点）はダメージとは別の数字で、こちらは 2〜3桁のまま
- 回復量は `Health.healed` を `DamageFeedback3D` が拾い、水色の数字で頭上に出す。
  毎フレーム入る踊り回復は `heal_number_interval`（0.35秒）ぶんをまとめて1つにする
  （検証: `tools/test_heal_number.gd`）
- リロード音は `assets/sfx/gun_reload.wav`（CC0 の実録音）。素材の長さに合わせて
  `reload_duration` を 1.3 秒にしてある
- 攻撃すると主人公の頭上へ擬音が出る（`fx/attack_cry_3d.gd`、銃「ぱん」／刀「ぶん」／
  素手「ふっ」／ドロップキック「でやあ」）。位置は頭のてっぺんから向いている方向へ
  頭ふたつぶん。字は Shippori Mincho B1 ExtraBold。購読するのは `PlayerWeapon.fired` /
  `PlayerKatanaCombo.stage_started` / `PlayerMelee.stage_started` /
  `PlayerAction.special_used` で、戦闘の処理には触らない。文字は出した場所に残るので、
  踏み込みの長いドロップキックでは本体が先へ出る
  （検証: `tools/test_attack_cry.gd`、見た目は `tools/capture_attack_cry.gd`）。
  敵には付けていない

### 回避・必殺

- 回避（`dodge`）: 無敵フレーム付きの短い移動。`Backflip` か `Running`（回避）を採用
- 必殺（`special` / △）: `Spin Flip Kick` で全方位に一撃。HP かゲージを少し消費

### 死亡モーション（共通）

通常敵と1〜4面ボスは `NpcAnimator.clip_down`、5面ニケはそのシーン固有の
`PlayerMelee.down_scene` に `mixamo_death_headshot.fbx`（Death Crouching Headshot Front）を割り当てる。
プレイヤーだけは残機消費後に復帰するため、Standing Death Backward 01 → Kip Up を使う。
`mixamo_death_headshot.fbx`（元尺1.900秒、素材の水平移動0.936m）と
`mixamo_death_backward_01.fbx`（元尺2.567秒、同1.368m）は、登録時と再生直前の双方で
`RootMotion.lock_horizontal()` を通し、Hips のX/Zを先頭キーへ固定する。上下動は残す。
`mixamo_kip_up.fbx` も同じ処理を通す。`NpcAnimator.clip_horizontal_drift()` と
`PlayerMelee.registered_horizontal_drift()` は、実際に再生する登録済みAnimationの先頭キーからの
最大水平移動量を返し、headless検証では各0.000mを期待する。

通常敵・1〜4面ボスと5面ニケは撃破から4.0秒後の消滅前、プレイヤーは3.0秒のダウンから
立ち上がりへ入る直前に `ModelBlink` を使う。既定は終了0.60秒前から周期0.16秒、最小不透明度0.82。
`ModelTint` の同じメッシュ収集結果を使うが、被弾フラッシュの `material_overlay` には触れず、
`GeometryInstance3D.transparency` だけを変える。`blink_started` / `opacity_changed` と
`is_blinking()` / `current_opacity()` をheadless検証用に公開する。通常の面遷移も既定4.0秒待ち、
ボスの点滅より先にシーンを切り替えない。カードでツリーが停止している間も点滅は進める。

### プレイヤーの武器・追加アクションモーション

`PlayerMelee` が所有する1本の `AnimationTree` と、コード生成のステートマシンを引き続き使う。
`player_melee.gd` は既に810行あったため、追加クリップのロードとステートノード生成は
`actors/player/player_action_anim.gd`（`PlayerActionAnim`）へ分離した。`.tscn` は補助ノードを配置する
だけで、AnimationLibrary・BlendTree・遷移を手書きしない。ゲームロジックは `PlayerMelee` の
`request_action()` / `set_gun_locomotion()` / `set_katana_locomotion()` を呼び、AnimationTree から
ゲームロジックへ戻る依存は作らない。

刀の3段化では `PlayerWeapon` が300行を超えていたため、段別タイマー・先行入力・判定形状は
`actors/player/player_katana_combo.gd`（`PlayerKatanaCombo`）へ分離する。`PlayerWeapon` は装備種別に
応じて `fire` を銃または刀へ渡し、素手では無視する。素手の `ComboTree` は変更せず、刀は同じ4物理フレームの
デバウンスと段ごとの先行入力を使う。初段85%・二段90%で受付を閉じ、窓外の入力では次段へ進まない。

|状態|素材の元尺|ロジック上の所要時間|既定の再生速度|判定・リリース|
|---|---:|---:|---:|---|
|刀待機 `katana_idle`|1.833秒|ループ|1.000倍|判定なし。停止時だけ使用|
|刀初段 `katana_1`|1.500秒|0.500秒（windup 0.12 + active 0.16 + recovery 0.22）|3.000倍|右腕角速度最大40% → 0.200秒。active 0.120〜0.280秒内。受付0〜0.425秒|
|刀二段 `katana_2`|2.400秒|0.600秒（windup 0.18 + active 0.20 + recovery 0.22）|4.000倍|右腕角速度最大33.3% → 0.200秒。active 0.180〜0.380秒内。受付0〜0.540秒|
|刀三段 `katana`|2.500秒|0.750秒（windup 0.20 + active 0.22 + recovery 0.33）|3.333倍|右腕角速度最大40% → 0.300秒。active 0.200〜0.420秒内。フィニッシュ|
|銃待機 `gun_idle`|3.800秒|ループ|1.000倍|判定なし|
|銃歩行 `gun_walk`|0.800秒|ループ|2.09m/sまでは1.000倍、超過分は実移動速度 / 2.09|判定なし|
|回避 `dodge`|2.167秒のうち 0.600〜1.400秒を切り出し（0.800秒）|`dodge_duration` 0.800秒|1.000倍|無敵 0.000〜0.800秒（切り出し区間の全体＝空中）|
|必殺 `special`|3.700秒のうち 0.680〜3.700秒を切り出し（3.020秒）|`special_cooldown` 1.632秒|1.850倍|回転蹴り56% → 0.914秒で範囲ダメージ|

必殺 `special` は素材の先頭 0.680秒（再生時間で 0.370秒）を `special_trim_start` /
`special_trim_end` で切り落とす。素材の頭には走り出す前の足踏みが入っており、そのまま出すと
前進しているのに走っていない絵になる。切り出し後の尺は 3.020秒。`special_cooldown` 1.632秒は
再生倍率の分母（クリップ長 / duration）とクールダウンを兼ね、`special_impact_ratio` 0.560 を
掛けた 0.914秒が着弾時刻になる。踏み込みは `special_lunge_start_time` 0.000秒から
`special_lunge_speed` 3.840m/s で始まり、実測の前進量は 3.456m（指定は
`special_lunge_distance` 3.500m）。

回避 `dodge` は Backflip 2.167秒のうち、踏み切り直前から接地直後までだけを使う。FBX は編集せず、
`AnimationNodeAnimation` の custom timeline（`use_custom_timeline` / `start_offset` /
`timeline_length`）で `dodge_trim_start` 0.600秒〜`dodge_trim_end` 1.400秒を切り出す。区間の根拠は
元クリップ（30fps）のボーン実測で、踏み切り 0.667秒、接地 1.333秒（第40フレーム）、沈み込み解消
1.800秒（第54フレーム）、立ち上がり完了 2.133秒（第64フレーム）。接地は `GeneralSkeleton` の FK
（`LeftToes` / `RightToes`）を1フレームずつ送って測った。Hips の高さは着地後も沈み込みで下がった
ままなので、接地の根拠には使えない。

`dodge_duration` は区間長と同じ 0.800秒。`PlayerActionAnim.configure_action()` は再生倍率を
「クリップ長 / duration」で決めるため、この値は回避ステートの寿命であると同時に再生速度の分母でも
あり、区間長と揃えることで 1.000倍になる。無敵 `dodge_iframes` も同じ 0.800秒（跳んでいる間の
全体）で、着地後の無防備な余韻は無い。

後退距離は初速ではなく `dodge_distance`（既定 2.85m）で指定する。初速を持つと距離が
`初速 * 継続 / 2` の従属値になり、継続を伸ばすと距離だけ連れて伸びるため。初速は
`dodge_duration` の終わりにちょうど止まる一定減速から `2 * dodge_distance / dodge_duration`
＝ 7.125m/s を逆算する（`player.gd::_dodge_launch_speed()`）。回避クリップは
`RootMotion.lock_horizontal()` で水平成分を潰してあるので、退く量はこの計算だけが決める。
画面端 clamp はカメラ半幅 4.765m − `screen_margin` 0.600m = 4.165m まで許すため、この距離では
端に張り付かない。奥行き `belt_z_min` / `belt_z_max` は回避が X 方向だけに動くため影響しない。

無敵は `Hurtbox.monitorable` を切ることで実現しているため、境界の検証では `Health` や
`receive_knockback` を直接呼ばず、本物の `Hitbox` を重ねて Area3D の検出経路から被弾させる。

実測は `tools/test_dodge_timing.gd`（素材の尺・ステート継続 0.800秒・再生倍率・移動 2.907m・
無敵終了 0.817秒＝1フレーム量子化・中断条件）と、`tools/capture_dodge.gd`
（`docs/img/qc_dodge_trim_*.png` で、目印のカプセルを越えて退くことを確認）で行う。

`mixamo_pickup.fbx` は拾う場面が未実装のため、素材登録だけとし AnimationLibrary へは読み込まない。

刀の40% / 33.3% / 40% と必殺の56%は FBX の手・腰・足のカーブ速度から求めた値で、それぞれ
`@export`（`stage_contact_ratios` / `special_impact_ratio`）として調整できる。効果はこのマーカー
時刻まで、ゲームロジック側のタイマーで遅らせる（入力直後に出すとモーションと判定が食い違う）。
素材またはアニメーション名を読めない場合は該当ステートを作らず、遅延もせずに効果を即座に出す。

銃装備中は、既存 `locomotion` 内の `gun_select`（Blend2）で銃待機(0.0)・銃歩行(1.0)の
BlendSpace1D サブツリーを選ぶ。0〜natural speed 2.09m/sで待機→歩行をブレンドし、2.09m/s以上は
歩行だけを使う。銃装備中だけキャラクターの移動速度を制限すると操作性が変わるため、移動速度は
最大4.5m/sのままにする。超過分はTimeScaleへ反映し、4.5/2.09=2.153倍で歩行周期を合わせる。
再生倍率上限 `pistol_walk_max_playback_scale` は `@export` で、既定2.2倍とする。

銃歩行は In Place 版で、Hips水平移動の実測は1ループ0.000mである。このため歩行クリップには
`RootMotion.lock_horizontal()` を適用せず、素材の上下動をそのまま使う。待機または歩行を読めない
場合は銃サブツリーを作らず、素手の locomotion を使う。

刀用は、銃セレクタの後段に `katana_select`（Blend2）を置き、刀装備かつ停止中だけ
`mixamo_sword_idle.fbx` を選ぶ。速度0.000〜0.100m/sで剣待機から既存 locomotion へブレンドし、
0.100m/s以上の歩行・走行は素手の idle/walk/jog をそのまま使う。剣待機は In Place 版で、
Hips水平移動の実測は1ループ0.000mであるため `RootMotion.lock_horizontal()` は適用しない。
素材またはアニメーション名を読めない場合は刀用ノードを作らず、素手の待機へフォールバックする。
刀を外すと `katana_select` を0へ戻す。トップレベルのステート名を常に `locomotion` に保つのは、
素手コンボ、dance、down/stand_up が共有してきた状態契約を変えないためである。被弾の Blend2
上半身レイヤーはルートの最後に重ねる。

武器GLBの実座標では、銃身はモデル+X・グリップは-Y、日本刀の刀身は-Z・柄は原点から+Z側にある。
世界座標の目標姿勢ではなく手の骨格を基準にし、`RightIndexProximal` →
`RightLittleProximal` の握り溝へ柄を沿わせる。日本刀の刀身は本来の握り方どおり人差し指側へ抜ける
局所向きとし、頭・髪との干渉は剣持ち専用の待機ポーズで避ける。握り位置は指を握り込んだ状態の
`RightIndexIntermediate` / `RightMiddleIntermediate` / `RightRingIntermediate` /
`RightLittleIntermediate` の平均とする。これは第2関節がつくる輪の中心であり、柄が収まる位置になる。
武器側の握り点は、メッシュ頂点の上下スライス重心を結んだ握り部の実軸上で取る。
銃は実軸の上端から35%、日本刀は実軸の中央を使う。実軸はモデルの座標軸とは一致しない。
手のひら法線方向の逃がしは銃+0.022m、日本刀+0.014mとする。既定値は
銃が回転(0.2,-179.9,64.5)〜(0.2,-179.9,82.2)（§17.3）・位置(0.0141,0.0885,0.0089)・
scale (0.12,0.12,0.12)、日本刀が
回転(10.5,-92.5,171.1)・位置(0.0737,0.1084,0.0351)・scale (0.40,0.40,0.50)。日本刀は
拳に対して柄が太いため、柄・鍔の太さに当たるモデルX/Yだけを0.50比80%の0.40へ縮め、刀身方向の
モデルZは0.50を維持する。これにより刀身長0.72mを変えずに柄と鍔だけを細くする。手の骨格を基準にした
局所値なので構え・歩行・斬りでも手に追従する。共有 `WeaponHolder` にはキャラクター固有値を持たせず、装着側が
`@export` 値として渡す。

`PlayerWeapon` はモデル座標の握り実軸と、スケール適用前のモデル半径を
`PlayerWeaponGrip` へ渡す。銃は上端(0.0993,-0.1167,0.0039)→下端(0.0410,-0.4347,0.0000) / 0.133333m、
日本刀は鍔側(0.0015,0.0028,0.0799)→柄頭側(-0.0005,0.0042,0.2664) / 0.038mとする。
武器ボスは同じ値を `WeaponLoadout` から同じmodifierへ渡す。
`player_weapon_grip_modifier.gd` は `SkeletonModifier3D` として Skeleton3D の直下で動き、
modifier 呼び出しごとに最新の `RightHand` ボーン姿勢と武器のローカルTransformを合成し、
モデル実軸をワールド線分へ変換する。BoneAttachment3DのNode更新順には依存しない。
半径も握り軸に直交する2方向の実スケール平均から毎回導出し、銃は0.016m、日本刀は
X/Y=0.40の適用後0.0152mになるため、軸別スケール変更後の太さに指ソルバーを追従させる。
これにより待機・歩行・斬りと銃の反動中も、1フレーム前の軸を使わない。

固定角度は使わず、`player_weapon_grip_solver.gd` が各関節の可動域を小さい角から
16分割で走査し、曲げ方向に最初に見つかる柄表面の交差を最大8回の二分探索で詰める。
許容誤差は0.002m。FKの親子関係に合わせ、Proximal回転でIntermediate、
Intermediate回転でDistal、Distal回転で最終節を延長した仮想指先を表面へ接地させる。
Proximal自身の原点は自身の回転では動かないため、武器の握りオフセットで接地させ、
modifier側はその表面誤差を診断値として保持する。

4本指の曲げ軸はローカル-Z、可動域は Proximal 0〜100度 / Intermediate 0〜120度 /
Distal 0〜80度。親指は反対側から押さえるローカル+Z、Metacarpal 0〜90度 /
Proximal 0〜110度 / Distal 0〜80度とする。軸、可動域、許容誤差、初期走査数、追加反復上限は
すべて `@export` とする。可動域内で交差が無い場合は最小誤差の角を使い、域端なら
`limited_joint_angles()` に記録する。`debug_solver_limits` を有効にすると未解決・クランプを1回だけ出力する。
角度は指ボーンだけに書き、素手では modifier を無効化して元のアニメーション出力へ戻す。
数値探索を別ファイルへ分けたのは、modifierの15ボーン適用責務と反復解法を分離し、
1ファイル300行超を避けるためである。

刀の段別既定値は、初段 damage 4000 / knockback 6.0 / reach 1.40m / lunge 2.5m/s、
二段 5000 / 7.5 / 1.65m / 2.8m/s、三段 7000 / 10.0 / 1.90m / 3.2m/s。
`KatanaHitbox` は各段の開始時に球の中心と半径を更新し、本体側の端を0.10mに固定したまま前方端だけを
1.40m→1.65m→1.90mへ伸ばす。追加2素材のどちらかを読めない場合は、`katana` だけを初段の
0.500秒・damage 4000 で再生する単発挙動へフォールバックする。

銃撃表示は `PlayerGunFx` が `HitscanGun.shot_fired` の結果を受け、`ProceduralGlow` と既存の
`CameraShake` の作法で銃口炎（0.120秒）、弾道（0.080秒）、命中光（0.120秒）、武器の後退
（0.140mを0.140秒で復帰）を出す。命中判定・ダメージは `HitscanGun` / `Hurtbox`
だけが所有する。`mixamo_rifle_fire.fbx` は両手で長物を構える全身トラックで、一丁拳銃の握りと
左手位置を崩すため使用しない。

HUDは銃装備中だけ残弾/最大弾数を表示する。残弾0で `fire` を押すと射撃せず、残弾欄を赤く点滅
させる。リロード中は残弾欄を「リロード中」へ切り替える。リロード用モーション素材は無いため、
AnimationTreeには新しいステートを追加せず、現在の銃待機・移動モーションを維持する。

必殺は開始0.100秒から3.000m/sで3.500m前進し、計算上1.267秒、物理更新順を含めて接触時刻
1.280秒までに助走を終える。全方位半径2.600mは残し、移動後の正面へ距離2.800m・
全幅1.400mの矩形判定をORで加える。正面距離は全方位半径を0.200mだけ越す値へ縮め、3.500mの
前進と旧3.400m判定が二重に過剰なリーチを作らないようにする。移動は `Player` の
`CharacterBody3D` が衝突と画面端 clamp を保ったまま処理し、判定時刻に停止する。

つかみ・必殺の対象選択は `PlayerAction` に残し、実ダメージは `Hurtbox.receive_area_hit()` へ渡す。
これにより通常攻撃と同じ `damage_applied`、被弾フラッシュ、加害者記録、ノックバック、
ヒットストップ、カメラシェイクを通す。この経路変更自体では対象選択や除外条件を変えない。

プレイヤーには down → 残機消費 → kip_up と別の死亡ステートがない。残機0でも down の終端を
保持してコンティニュー待ちへ入る同一フローであるため、`mixamo_death_headshot.fbx` はロード・
リターゲットだけを検証し、プレイヤーの AnimationTree には割り当てない。down を死亡へ差し替えない。

3面ボスはch15にライフルを装着し、奥行き差0.45m以内で3.0m未満なら後退、4.5mを越えたら接近、
その間で正面内積0.95以上になってから撃つ。既定値はdamage 5000、射程18m、発射間隔1.2秒、
1回につき5連射（間隔0.18秒）で、すべて `@export`。保つ距離を画面の見える半幅（4.7m前後）より内側に取るのは、後退した
ボスが画面外へ出るとプレイヤーが追えず倒せなくなるため（§8.2.1）。

バーストの2発目以降は、1発目を撃ったときの狙い点（`_burst_target`）へ撃つ。相手の現在位置を
読み直すと、撃たれ始めてから段を外しても残り4発が追ってきて、「段をずらせば当たらない」という
約束が5発中4発で崩れる。射撃ステートを抜けるときは `_cancel_burst()` で撃ち残しを捨てる。
残したまま怯むと、戻ってきた瞬間に古い残弾が発射間隔を無視して出る
（検証: `tools/test_gun_boss_burst_gates.gd`）。

4面ボスの拳銃は素材が発砲クリップ1本しか無いので、`NpcAnimator.idle_static_pose` を立てて
その先頭フレームを1枚の姿勢として待機に登録し、撃つ瞬間だけ同じ素材を `clip_fire` として
差し込む（プレイヤー側の `_freeze_pose` と同じ考え方。§17.1）。立てないと待機が発砲の反動を
回し続け、しかも撃った瞬間には何も起きない。2面ボスはswatに刀を装着し、
既存 `APPROACH → ATTACK` で上記の初段相当を出す。4面ボスはch16_bossに主人公と同じ拳銃を
装着し、盾を放したあとは同じ `GUN_COMBAT` で撃つ（§8.3）。どれも `WeaponHolder` /
`WeaponLoadout` と同じ指modifierを使う。

`tools/verify_player_action_motions.gd` は10素材のロード、GeneralSkeleton とプロファイルボーントラック、
AnimationLibrary、コード生成ステート、素材の実尺、上表の再生速度と判定時刻を headless で検証する。
`tools/test_character_anim.gd` は全キャラクターへの共通モーション適用を、
`tools/test_enemy_boss_loadouts.tscn` は面ごとのモデル割り当て、死亡クリップ、武器装着、指modifier、
3面ボスと4面ボスの射撃に加え、登録済み死亡クリップの水平移動0mをheadlessで検証する。
`tools/test_player_down.tscn` は登録済みdown / kip_upの水平移動0mと、復帰直前の点滅開始・不透明度変化も
検証する。`tools/test_enemy_ai.tscn` と `tools/test_nike_boss.tscn` は撃破後の点滅と消滅も確認する。
`tools/test_chain.tscn` は2・3面それぞれのlock→波→GO→boss→clear、波数、ch06（色違いを含む）、
幕間文言、3面ボスの出現間合いを通しで確認する。
`tools/test_stage4_zombies.tscn` は4面のゾンビの波、ボス戦に加わる Ch30、面の題名の表示と、
詰められた3面ボスが画面外へ出ないこと（§8.2.1）を headless で確認する。

## 15. 入力マップ

`project.godot` の `[input]`。キーボードは物理キー配列で登録する。遊ぶ側から見た説明は
`docs/controls.md`。

|アクション|キーボード|パッド（PS 表記）|備考|
|---|---|---|---|
|`move_left` / `move_right`|A / D|左スティック・十字 左右|X|
|`move_forward` / `move_back`|W / S|左スティック・十字 上下|Z（奥 / 手前）|
|`attack`|J|□|素手コンボのパンチ入力|
|`kick`|K|×|素手コンボのキック入力|
|`interact`|E|○|踊り回復（長押し）|
|`fire`|U|R2|銃を撃つ／刀で斬る。素手では何もしない|
|`reload`|R|L2|銃を1.3秒でリロード|
|`switch_weapon`|Tab|L1|素手 → 日本刀 → 銃 を循環|
|`dodge`|Space|R1|回避（バックフリップ）|
|`special`|O|△|必殺（回転飛び蹴り）|
|`ui_accept`|Enter / テンキー Enter / Space|○ / Options|カードを進める・閉じる・コンティニュー・結果画面を閉じる|

`ui_accept` は `project.godot` で既定を上書きしてある（× は外し、○ と Options を入れる）。
Space が `dodge` と `ui_accept`、○ が `interact` と `ui_accept` に重なるが、カード・タイトル・
結果画面ではツリーが止まっているか本体が居ないため競合しない。カードのスキップ（Esc / △）は
入力マップを通さず `ui/text_card.gd` がキーとボタンを直接読む。

## 16. 得点・結果画面・効果音

### 16.1 得点

保持は `RunState`（唯一のグローバル可変状態）。加点の条件は `actors/player/player_score.gd`
1か所に集め、既存の命中通知（`Hitbox.hit_landed` / `PlayerWeapon.shot_hit`）を購読するだけで、
ダメージ計算や当たり判定には触らない。

|加点|値|備考|
|---|---:|---|
|素手が当たる|100 × 段数|`PlayerMelee.stage_started` の段を掛ける|
|日本刀が当たる|60 × 段数|`PlayerKatanaCombo.current_stage()` を掛ける|
|銃が当たる|30|段は無いので常に 1 倍|
|敵を倒す|200|武器によらず同じ|
|死亡|−500|0 未満にはしない|

段を掛けるので、繋げるほど1発の価値が上がる（素手7段なら 100×(1+…+7)=2800 で、
単発7回の 700 の4倍）。値はすべて `RunState` の `@export`。

### 16.2 結果画面

`ui/result_panel.tscn`。最終面のクリアとゲームオーバーの両方で `BeltStage._finish_game()`
から出す。テキストカードと同じくツリーを一時停止し、閉じてから `RunState.reset()` を呼ぶ
（先に呼ぶと出す得点が消える）。「X に投稿」は
`https://x.com/intent/post?text=` に `私は #AIニケちゃん で N,NNN 回ヌキました（2025年8月からの累計）` を URI エンコードして
`OS.shell_open()`。閉じるとタイトル画面へ戻る。

### 16.3 効果音

`autoload/sfx.gd`。`assets/sfx/*.wav` は CC0 の実録音から一撃ぶんを切り出したもの
（取得元は `assets/sfx/SOURCES.md`、一覧は `docs/asset-credits.md`）。呼び出しは `actors/player/player_sfx.gd`、`Enemy._on_downed`、
`GunBoss._on_shot_fired`（発砲音。3面ボスは `rifle_shot`）の3か所だけにまとめ、
戦闘の処理には触らない。
被弾・ダウンの掛け声は別系統で、§16.5 の `VoiceReactions` が持つ。

### 16.4 3面ボスの武器

3面ボス GUNNER はライフル（`assets/weapons/rifle.glb`）を両手で構える。モーションは
Mixamo Shooter Pack（`mixamo_rifle_idle` / `_walk` / `_run`）で、握りの数値と実測値の
根拠は `docs/asset-credits.md` にある。

発砲は `GunBoss._play_fire_reaction()` が `NpcAnimator.play_one_shot()` で差し込む。
`HitscanGun.fire_at()` の直後に呼び、`fire_reaction_duration`（既定 0.4 秒。
`gun_fire_interval` を超えないよう clamp する）だけ移動のクリップを止める。
`play()` ではなく `play_one_shot()` を使うのは、GUN_COMBAT が毎物理フレーム
`drive_locomotion()` を呼ぶため、素直に `play()` すると次のフレームで潰されるからである。

このために `NpcAnimator` へ `Clip.FIRE` と `clip_fire` を足した（列挙の末尾へ追加した
ので既存の値は動かない）。近接の `clip_attack` と分けたのは、銃の敵が撃つ絵と殴る絵の
両方を持ちうるため。`clip_fire` 未設定の個体では何も差し込まない。

銃口炎・弾道・薬莢・反動は、プレイヤーと同じ `actors/player/player_gun_fx.gd` を
ボスの `GunFx` ノードに置き、`HitscanGun.shot_fired` を購読して出す。発砲音は
`Sfx.play(fire_sound)`（3面ボスは `rifle_shot`）。どちらも撃った事実だけを見ており、
射撃判定には触らない。表示部品が無い個体ではその分を黙って飛ばす。

**銃口は武器モデルに追従させる。** `_update_muzzle_position()` は装備中の武器モデルの
先端（本体の正面方向へ最も突き出た頂点。装備のたびに1度だけ測る）へ `HitscanGun` を置く。
本体からの固定オフセットにすると、腕が動く発砲・歩き・走りで銃口炎が銃の先から離れる
（実測で待機と発砲の間に 9.3 cm 動く）。

`gun_muzzle_height`（1.05）は**狙う高さ**で、銃口の位置ではない。本体の原点からの高さで
測るので、狙い点のワールド高さは `ボスの y + gun_muzzle_height`。ボスは `y = 0.2` に立つ
ため、銃口の高さ（1.59）を入れると狙い点が 1.79 m になり、当たり判定の上端 1.70 m を
超えて当たらない。1.05 なら 1.25 m で胸に入る。
`gun_muzzle_forward_offset` は武器モデルを持たない個体の代替。確かめ方は
`tools/probe_barrel_aim.gd`（実際にレイを飛ばして命中点を出す）。

**銃口炎の向きは敵専用の部品で直す。** `actors/enemy/enemy_gun_fx.gd` が
`PlayerGunFx` を継承し、`_spawn_muzzle_flash()` だけを上書きして、出した炎を撃った向きへ
回す。元の実装は向きに `facing`（±X）しか使わず銃口炎が常に水平で、傾いた弾道と食い違う。
プレイヤー側の見た目は変えない。銃身の向きではなく**弾の向き**へ合わせている
（両者は 7 度ほどずれる。銃身はやや上、弾は胸へ向けて下）。

検証は `tools/test_gun_boss_fire.gd`（クリップ登録、撃つと単発再生が始まること、
移動中でも潰されないこと、差し込む秒数が発射間隔を超えないこと、撃つと表示が生成され
発砲音が設定されていること）。

### 16.5 被弾・ダウンの掛け声

`actors/shared/voice_reactions.gd`。`Health.staggered` / `Health.downed` を購読して鳴らすだけで、
戦闘の処理には触らない（`player_sfx.gd` と同じ形）。素材は `assets/voice/*.wav`（自作。
`docs/asset-credits.md`）。

`Sfx` autoload を経由しない。あちらは名前1つに波形1つを対応させる作りで、変化形の抽選も
話者ごとの排他も持たないため。声の組はスクリプトに書かず、`.tscn` の `@export` で渡す。

|置き場所|被弾|ダウン|
|---|---|---|
|`actors/player/player.tscn`|`ai_nike_hurt_a/b/c`|`ai_nike_down_a/b`|
|`actors/enemy/enemy.tscn`|`enemy_hurt_a/b/c`|`enemy_down`|
|`actors/boss/nike.tscn`|`ai_nike_hurt_a/b/c`|`ai_nike_down_a/b`|

役割別の敵シーンは `enemy.tscn` を継承するので、基底に置いた1つが全種類へ効く。ボスの声を
AIニケちゃんと分けるなら `nike.tscn` の `hurt_clips` / `down_clips` を差し替える。

1体につき `AudioStreamPlayer` を1本しか持たない。同じキャラの声は重ならず、連続被弾では
前の声を切って鳴らし直す。被弾は `hurt_chance`（敵 0.4 / プレイヤー 0.5）で間引き、
`hurt_interval`（0.7 秒）を下限に置く。コンボの全段で叫ばせないための調整で、ダウンは
抽選も間隔も掛けず必ず鳴らす。

検証は `tools/test_voice_reactions.gd`（3シーンの結線、ループ無効、シグナルからの再生、
再生枠が1本であること、間隔が効くこと）。

### 16.6 攻撃設定の距離範囲

`Enemy` が ATTACK へ入る条件は `|dx| <= attack_range` かつ `|dz| <= attack_depth_tolerance`
だが、`EnemyAttackProfile` の選択は平面距離 `sqrt(dx^2+dz^2)` で見る。両者がずれるので、
1種類しか profile を持たない敵では、射程の隅（attack_range 1.4 なら最大 1.471）と至近距離が
候補から漏れ、profile 無しの既定値（damage 12・既定のタイミング）で振ってしまう。刀のボスなら
40 が 12 に落ちる。単一 profile の敵は `min_distance = 0.0` とし、`max_distance` を
`sqrt(attack_range^2 + attack_depth_tolerance^2)` より広く取る（現状 1.5）。

### 16.7 武器の順

`PlayerWeapon` は素手で始まり、`switch_weapon` で 素手 → 日本刀 → 銃 → 素手 と巡回する。
銃は `reload`（R）でリロードでき、持ち替えても残弾は保持する。


## 17. プレイヤーの拳銃

### 17.1 構えは静止、撃った瞬間だけ動く

素材は Mixamo の `Shooting`（`mixamo_pistol_fire.fbx`、1.167 秒の発砲1回ぶん）1本で、
`PlayerActionAnim` が構えと発砲の2つに分けて使う。

- **構え**（`gun_idle`）: `_freeze_pose()` が素材の `pistol_idle_pose_time`（既定 0.000 秒）
  の姿勢をトラックごとにキー1本へ落とし込む。キーが1本しか無いので、区間のどこを再生しても
  姿勢が変わらない。銃を持って止まっている間はここから動かない。
- **発砲**（`gun_fire`）: 同じ素材を丸ごとライブラリへ入れ、`AnimationNodeOneShot`
  （`gun` ブレンドツリーの `fire` ノード）で構えの上へ一度だけ重ねる。区間は
  `AnimationNodeAnimation` の custom timeline で `pistol_fire_trim_start` /
  `_end`（既定 0.130〜1.167 秒）に絞る。**素材そのものは編集しない。**

`PlayerWeapon._try_fire()` → `PlayerMelee.play_gun_fire()` → `PlayerActionAnim.play_gun_fire()`
が `parameters/main/locomotion/gun/fire/request` へ `ONE_SHOT_REQUEST_FIRE` を書くだけで、
ステート遷移も歩行のブレンドも触らない（撃ちながら歩いても locomotion の進行は変わらない）。

3面ボスの `NpcAnimator.play_one_shot()` と同じ考え方だが、プレイヤー側は毎フレーム
locomotion を指定し直しても潰れないよう、ステートではなくブレンドツリー内の OneShot で行う。

OneShot は上半身のトラックだけに掛ける（`PlayerActionAnim._filter_to_upper_body`）。素材は
全身1本なので、絞らないと重なっている約 1.0 秒のあいだ脚まで発砲クリップの立ち姿勢になり、
撃った直後に歩いても銃持ち歩行の絵にならない。除外する下半身は被弾レイヤーと同じ
`PlayerMelee.LOWER_BODY_BONES`（Root / Hips / 両脚 / 両足 / 両つま先）で、`add_weapon_locomotion()`
の引数として渡す。実測では、絞らない場合に両足の高低差が 0.158m → 0.055m まで潰れ、撃たずに
歩いたときとの足の高さの差が 0.080m 開く。絞ると 0.002m まで揃う
（検証: `tools/test_gun_fire_walk.gd`、見た目は `tools/capture_gun_fire_walk.gd`）。

### 17.2 構えと歩行で握りの角度を変える

銃身（武器モデルの +X）の仰角は、構えと歩行で腕の姿勢が違うぶんだけ変わる。握りの角度を
1つに固定すると、どちらかが傾く。実測（`tools/test_player_gun.gd` の (8)）。

|握りの `z`|構え|歩行の平均|
|---|---:|---:|
|80.6（固定）|+13.1 度|−4.1 度|
|64.5（固定）|−3.0 度|−20.2 度|
|64.5 ↔ 82.2（速度で混ぜる）|−3.0 度|−2.5 度|

`PlayerWeapon._update_pistol_grip_rotation()` が本体の水平速度から
`pistol_grip_blend_speed`（2.09 m/s。銃歩行のブレンドと同じ基準）で割合を出し、
`pistol_grip_rotation`（構え）と `pistol_grip_rotation_walk`（歩行）を混ぜて
`WeaponHolder.set_grip_rotation()` へ渡す。発砲の跳ね上がりは上半身のレイヤーが作るので、
この補正では消えない。

**モデルの +X は、描画される銃身より 3 度下に出る。** そのため目標は 0 度ではなく −3.0 度。
この 3 度は `docs/img/qc_gunpitch_player_*.png` の銃身上端を直線当てはめして測った
（構えの見た目は +15.8 度 → −0.2 度）。撮り直しは `tools/capture_gun_pitch.gd`。

4面ボスは同じ握り値で構えが −5.9 度（ほぼ水平）なので混ぜない。VRM（プレイヤー）と
Mixamo（敵）で手ボーンの姿勢が違い、同じ値でも結果が変わる。

### 17.3 銃口は武器モデルの先端へ追従させる

3面ボスと同じ方式をプレイヤーにも入れた。測り方は `actors/shared/muzzle_tip.gd`
（`MuzzleTip.measure_local()`）に集約し、`GunBoss` もこれを呼ぶ。

`PlayerWeapon._update_muzzle_position()` が、装備中の武器モデルの中で**本体の正面方向へ
最も突き出た頂点**を求め、そこへ `HitscanGun` を置く。頂点を総なめするので、武器か向きが
変わったときだけ測り直してモデルのローカル座標で覚えておく。武器モデルが取れないときだけ、
`muzzle_height` / `muzzle_forward_offset` の固定オフセットで代替する。

射線は銃口から正面 ±X へ水平。原点は銃の先端（実測で本体から 1.425 m の高さ）で、敵の
当たり判定は 0.20〜1.90 m の範囲にあるため胸の高さに入る。一撃即死は当たりどころではなく
確率で決めている。

`PlayerGunFx.muzzle_forward_offset` は 0 にする（`player.tscn` / `stage_3_boss.tscn` /
`stage_4_boss.tscn` で明示）。この値は射線の原点が本体固定だったころに銃口炎を前へ寄せるための
もので、原点が銃の先端になった構成ではスクリプトの既定値 0.16 のままだと炎が銃の先から
16 cm 浮く。
