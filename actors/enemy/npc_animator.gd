class_name NpcAnimator
extends Node

## NPC の見た目（`Model` 以下のキャラクター）へモーションを再生する。
##
## ステートマシンがこのノードを駆動する。逆向きの依存（アニメ側が NPC の状態を
## 読む）は作らない。`Model` 以下にはノードを足さない方針のため、AnimationPlayer
## はこのノードの子に置き、`root_node` だけをキャラクターのルートへ向ける。
##
## 素材は Mixamo モーション FBX（リターゲット済み）。同じ FBX を NPC ごとに
## インスタンス化すると起動が遅くなるため、取り出した Animation は静的に共有する。

enum Clip { IDLE, WALK, RUN, HIT, DOWN, PRONE, ATTACK, STAND, KNOCKBACK, HIT_SMALL,
	ATTACK_JAB, ATTACK_HOOK, FIRE }

## FBX から取り出すクリップ名。Godot の ufbx が Mixamo の FBX に付ける名前。
const FBX_CLIP_NAME: String = "mixamo_com"
## 静止ポーズ用クリップの長さ（秒）。0 だとブレンドの進行が計算できないため、
## 十分短い値を入れてループさせる。
const STATIC_CLIP_LENGTH: float = 0.1

## FBX から取り出した Animation の共有キャッシュ。キーは FBX のリソースパス。
static var _clip_cache: Dictionary = {}

@export var model_path: NodePath = ^"../Model"
## 既定のクロスフェード秒数。
@export var blend_time: float = 0.15
## この速度未満は待機とみなす（m/s）。
@export var idle_speed_threshold: float = 0.2
## WALK と RUN を切り替える速度。CHASE の 3.2 m/s は RUN 側へ入れる。
@export var run_speed_threshold: float = 2.6
## クリップを等速再生したときに見た目の歩幅が合う自然速度（m/s）。
@export var walk_natural_speed: float = 2.0
@export var run_natural_speed: float = 4.5
## 実速度同期で許可する再生倍率の範囲。
@export var locomotion_speed_limits: Vector2 = Vector2(0.55, 1.5)
## Hips の水平移動（ルートモーション）を殺す。理由と実測値は `RootMotion` を参照。
@export var lock_root_motion: bool = true

@export_group("Clips")
@export var clip_idle: PackedScene
## clip_idle を先頭フレームで止めた1枚の姿勢として登録する。撃つ絵しか素材が無い
## 個体（拳銃の構えを発砲クリップの先頭から取る4面ボス）で使う。false なら
## クリップをそのままループさせる。
@export var idle_static_pose: bool = false
@export var clip_walk: PackedScene
@export var clip_run: PackedScene
## 被弾のけぞり（小）。その場で頭を振られるだけ。
@export var clip_hit: PackedScene
## 被弾のけぞり（大）。ノックバックを伴う被弾で使う。未設定なら clip_hit を使う。
@export var clip_knockback: PackedScene
## 被弾のけぞり（軽）。poise で耐えた被弾に、ステートを変えずに一瞬だけ差し込む。
@export var clip_hit_small: PackedScene
## 敵・ボスの死亡。共通の headshot クリップを最後まで再生する。
@export var clip_down: PackedScene
## 伏せ。うつ伏せの姿勢で静止させるため、最終フレームだけを使う。
@export var clip_prone: PackedScene
## 攻撃。プレイヤー用の .res はヒットボックスを開く Call Method Track を持つので
## 流用せず、素の Mixamo クリップを使う。
@export var clip_attack: PackedScene
## 銃の発砲。撃つ瞬間に一度だけ差し込む。近接の clip_attack とは別枠にする
## （銃の敵は撃つ絵と殴る絵の両方を持ちうるため）。未設定なら何も差し込まない。
@export var clip_fire: PackedScene
## 何もしていない立ち姿。既存の待機（clip_idle）はボクシングの構えであり、
## 人質には使えない。歩行クリップの先頭フレーム（直立）を静止させて代用する。
## 専用の待機モーションを入れたらここを差し替える。
@export var clip_stand: PackedScene
@export_group("")

var _player: AnimationPlayer = null
var _model: Node3D = null
var _names: Dictionary = {}
var _current: int = -1
var _attack_clip_scenes: Dictionary = {}
## ワンショット再生の残り秒数。尽きるまで drive_locomotion() を無視する。
## 無視しないと、CHASE 等が毎物理フレーム play(IDLE) を呼び、ステートを変えずに
## 差し込んだクリップが次のフレームで潰される。
var _one_shot_left: float = 0.0


func _physics_process(delta: float) -> void:
	if _one_shot_left > 0.0:
		_one_shot_left = maxf(_one_shot_left - delta, 0.0)


## 初期化。子の `_ready()` は親より先に走り、その時点では `Model` がまだ空なので、
## キャラクターを差し込んだ NPC 本体から明示的に呼ばせる。
func setup() -> void:
	_model = get_node_or_null(model_path) as Node3D
	if _model == null:
		push_warning("npc_animator: Model が無い")
		return
	var character: Node3D = _find_skinned_root(_model)
	if character == null:
		# プリミティブ表示のままの個体（テスト用ステージなど）では何もしない。
		return

	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.root_node = _player.get_path_to(character)

	var library := AnimationLibrary.new()
	var idle_clip: Animation = _load_fbx_clip(clip_idle)
	if idle_static_pose:
		idle_clip = _make_static_clip(idle_clip, 0.0)
	_register(library, Clip.IDLE, idle_clip, Animation.LOOP_LINEAR)
	_register(library, Clip.WALK, _load_fbx_clip(clip_walk), Animation.LOOP_LINEAR)
	_register(library, Clip.RUN, _load_fbx_clip(clip_run), Animation.LOOP_LINEAR)
	_register(library, Clip.HIT, _load_fbx_clip(clip_hit), Animation.LOOP_NONE)
	_register(library, Clip.KNOCKBACK, _load_fbx_clip(clip_knockback), Animation.LOOP_NONE)
	_register(library, Clip.HIT_SMALL, _load_fbx_clip(clip_hit_small), Animation.LOOP_NONE)
	_register(library, Clip.DOWN, _load_fbx_clip(clip_down), Animation.LOOP_NONE)
	# 静止ポーズは「その1フレームだけのループクリップ」にして登録する。
	# AnimationPlayer を pause() で止める方式だと、クロスフェードの途中で
	# 固まって中途半端な姿勢（伏せと立ちの中間）になる。
	_register(library, Clip.PRONE,
		_make_static_clip(_load_fbx_clip(clip_prone), -1.0), Animation.LOOP_LINEAR)
	_register(library, Clip.ATTACK, _load_fbx_clip(clip_attack), Animation.LOOP_NONE)
	for clip_id: int in _attack_clip_scenes:
		_register(library, clip_id,
			_load_fbx_clip(_attack_clip_scenes[clip_id] as PackedScene), Animation.LOOP_NONE)
	_register(library, Clip.FIRE, _load_fbx_clip(clip_fire), Animation.LOOP_NONE)
	_register(library, Clip.STAND,
		_make_static_clip(_load_fbx_clip(clip_stand), 0.0), Animation.LOOP_LINEAR)
	_player.add_animation_library(&"npc", library)


## 再生できる状態か。プリミティブ表示のままの個体では false。
func is_active() -> bool:
	return _player != null


## そのクリップが登録されているか。素材が無いときの代替を選ぶのに使う。
func has_clip(clip: int) -> bool:
	return _names.has(clip)


## 攻撃設定が持つ素材を setup() 前に登録する。
func configure_attack_clip(clip: int, scene: PackedScene) -> void:
	if scene != null:
		_attack_clip_scenes[clip] = scene


## 速度から待機・歩き・走りを選ぶ。ワンショット再生中は上書きしない。
func drive_locomotion(horizontal_speed: float) -> void:
	if _one_shot_left > 0.0:
		return
	if horizontal_speed >= run_speed_threshold:
		_play_locomotion(Clip.RUN, horizontal_speed, run_natural_speed)
	elif horizontal_speed >= idle_speed_threshold:
		_play_locomotion(Clip.WALK, horizontal_speed, walk_natural_speed)
	elif _names.has(Clip.IDLE):
		play(Clip.IDLE)
	else:
		# 客のように待機の構えを持たない個体は直立で止める。
		play(Clip.STAND)


func _play_locomotion(clip: int, horizontal_speed: float, natural_speed: float) -> void:
	play(clip)
	if _player == null or natural_speed <= 0.0:
		return
	_player.speed_scale = clampf(horizontal_speed / natural_speed,
		locomotion_speed_limits.x, locomotion_speed_limits.y)


## クリップの長さ（秒）。単発クリップをステートの所要時間へ合わせるのに使う。
func clip_length(clip: int) -> float:
	if _player == null or not _names.has(clip):
		return 0.0
	return _player.get_animation(_names[clip]).length


## 登録後、実際に再生するクリップの最大水平移動量（m）。headless 検証用。
func clip_horizontal_drift(clip: int) -> float:
	if _player == null or not _names.has(clip):
		return -1.0
	return RootMotion.horizontal_max_drift(_player.get_animation(_names[clip]))


## 同じクリップの再指定は無視する（毎フレーム呼ばれても再生位置が飛ばない）。
## 連続被弾のように頭から再生し直したい場合だけ force を立てる。
## from_position はクリップ先頭の無反応区間を飛ばす開始位置（秒）。
func play(clip: int, custom_blend: float = -1.0, speed_scale: float = 1.0,
		force: bool = false, from_position: float = 0.0) -> void:
	if _player == null or not _names.has(clip):
		return
	# 死亡は登録時の複製だけに頼らず、AnimationPlayer が実際に再生する最終リソースも
	# 直前に固定する。ライブラリ差し替え後も Hips の水平移動を持ち込ませない。
	if clip == Clip.DOWN and lock_root_motion:
		RootMotion.lock_horizontal(_player.get_animation(_names[clip]))
	if _current == clip and not force:
		return
	# ステートに紐づく再生はワンショットより優先する。
	_one_shot_left = 0.0
	_current = clip
	# locomotion が設定した全体倍率を単発クリップへ持ち越さない。
	_player.speed_scale = 1.0
	_player.play(_names[clip], custom_blend if custom_blend >= 0.0 else blend_time,
		speed_scale)
	if from_position > 0.0:
		_player.seek(from_position, false)


## ステートを変えずに単発クリップを一瞬だけ差し込む（耐え被弾の軽いのけぞり用）。
## duration 秒に収まるよう再生速度を合わせ、その間 drive_locomotion() を無視する。
## start_time はクリップ先頭の無反応区間を飛ばす開始位置（元クリップ基準の秒）。
func play_one_shot(clip: int, duration: float, start_time: float = 0.0) -> void:
	if _player == null or not _names.has(clip) or duration <= 0.0:
		return
	var remain: float = clip_length(clip) - start_time
	if remain <= 0.0:
		return
	_one_shot_left = duration
	_current = clip
	_player.speed_scale = 1.0
	_player.play(_names[clip], blend_time, remain / duration)
	if start_time > 0.0:
		_player.seek(start_time, false)


## ワンショット再生中か。ガードの構えのような定常再生が、差し込んだクリップを
## 上書きしない判断に使う。
func is_one_shot_active() -> bool:
	return _one_shot_left > 0.0


## クリップの time 時点の姿勢だけを持つ、長さ 0 の静止クリップを作る。
## time が負なら最終フレーム。位置・回転・拡縮トラックのみを写す。
func _make_static_clip(animation: Animation, time: float) -> Animation:
	if animation == null:
		return null
	var at: float = time if time >= 0.0 else animation.length
	var static_clip := Animation.new()
	static_clip.length = STATIC_CLIP_LENGTH
	for track in range(animation.get_track_count()):
		var type: int = animation.track_get_type(track)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D \
				and type != Animation.TYPE_SCALE_3D:
			continue
		var index: int = static_clip.add_track(type)
		static_clip.track_set_path(index, animation.track_get_path(track))
		match type:
			Animation.TYPE_POSITION_3D:
				static_clip.position_track_insert_key(index, 0.0,
					animation.position_track_interpolate(track, at))
			Animation.TYPE_ROTATION_3D:
				static_clip.rotation_track_insert_key(index, 0.0,
					animation.rotation_track_interpolate(track, at))
			Animation.TYPE_SCALE_3D:
				static_clip.scale_track_insert_key(index, 0.0,
					animation.scale_track_interpolate(track, at))
	return static_clip


func _register(library: AnimationLibrary, clip: int, animation: Animation,
		loop_mode: Animation.LoopMode) -> void:
	if animation == null:
		return
	var copy: Animation = animation.duplicate(true) as Animation
	copy.loop_mode = loop_mode
	if lock_root_motion:
		RootMotion.lock_horizontal(copy)
	var name := StringName("clip_%d" % clip)
	library.add_animation(name, copy)
	_names[clip] = StringName("npc/%s" % name)


func _load_fbx_clip(scene: PackedScene) -> Animation:
	if scene == null:
		return null
	var key: String = scene.resource_path
	if _clip_cache.has(key):
		return _clip_cache[key] as Animation
	var inst: Node = scene.instantiate()
	var source: AnimationPlayer = _find_anim_player(inst)
	var clip: Animation = null
	if source != null and source.has_animation(FBX_CLIP_NAME):
		clip = source.get_animation(FBX_CLIP_NAME).duplicate() as Animation
	inst.free()
	_clip_cache[key] = clip
	return clip


## スキンを持つメッシュがぶら下がっているルート（FBX のルート Node3D）を探す。
func _find_skinned_root(node: Node) -> Node3D:
	for child in node.get_children():
		if _find_skeleton(child) != null:
			return child as Node3D
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_anim_player(child)
		if found != null:
			return found
	return null
