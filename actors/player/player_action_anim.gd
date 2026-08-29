extends Node
class_name PlayerActionAnim

## PlayerMelee がコード生成する AnimationTree へ、武器・追加アクションの
## クリップとステートノードを供給する。ゲームロジックは参照せず、AnimationTree
## からロジックへ戻る依存も作らない。

## 刀コンボ。既存の katana 名は三段目兼、追加2素材が読めない場合の単発フォールバックに残す。
const ACTION_KATANA_1: StringName = &"katana_1"
const ACTION_KATANA_2: StringName = &"katana_2"
const ACTION_KATANA: StringName = &"katana"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_SPECIAL: StringName = &"special"
const GUN_LOCOMOTION_NODE: StringName = &"gun"
const GUN_SELECT_NODE: StringName = &"gun_select"
const KATANA_IDLE_NODE: StringName = &"katana_idle"
const KATANA_SELECT_NODE: StringName = &"katana_select"

const ACTION_STATES: Array[StringName] = [
	ACTION_KATANA_1,
	ACTION_KATANA_2,
	ACTION_KATANA,
	ACTION_DODGE,
	ACTION_SPECIAL,
]
const PLAYER_LIBRARY_PREFIX: String = "player/"
const GUN_IDLE_ANIMATION: StringName = &"gun_idle"
const GUN_WALK_ANIMATION: StringName = &"gun_walk"
const GUN_FIRE_ANIMATION: StringName = &"gun_fire"
const GUN_FIRE_NODE: StringName = &"fire"
const GUN_FIRE_CLIP_NODE: StringName = &"fire_clip"
const KATANA_IDLE_ANIMATION: StringName = &"katana_idle"
## 静止させた構えの尺（秒）。キーが1本ずつしか無いので、どの時刻でも同じ姿勢になる。
const FROZEN_POSE_LENGTH: float = 0.1
const STATE_COLUMN_X: float = 300.0
const STATE_ROW_Y: float = 330.0
const STATE_GAP_X: float = 250.0
const MIN_MOVING_SPEED: float = 0.1
const MIN_NATURAL_SPEED: float = 0.01
const MIN_PLAYBACK_SCALE: float = 1.0
## これより短い切り出しは指定ミスとみなし、切り出さず全長を使う（秒）。
const MIN_TRIM_LENGTH: float = 0.01
const GUN_WALK_BLEND_POSITION: float = 1.0
const GUN_BLEND_POSITION_PARAMETER: String = \
	"parameters/main/locomotion/gun/blend/blend_position"
const GUN_SPEED_SCALE_PARAMETER: String = \
	"parameters/main/locomotion/gun/speed/scale"
const GUN_SELECT_PARAMETER: String = \
	"parameters/main/locomotion/gun_select/blend_amount"
const GUN_FIRE_REQUEST_PARAMETER: String = \
	"parameters/main/locomotion/gun/fire/request"
const KATANA_SELECT_PARAMETER: String = \
	"parameters/main/locomotion/katana_select/blend_amount"

@export_group("Gun Locomotion Clips")
## 銃の構えと発砲の素材。構えは撃っていない間ずっと出るので動かさず、この素材の
## 1瞬を静止させて使う。撃った瞬間だけ、同じ素材の発砲1回ぶんを上へ重ねる。
@export_file("*.gltf", "*.fbx") var pistol_idle_scene: String = \
	"res://assets/motions/mixamo_pistol_fire.fbx"
@export var pistol_idle_key: String = "mixamo_com"
## 構えとして静止させる時刻（秒）。素材の中でこの姿勢だけを取り出す。
@export var pistol_idle_pose_time: float = 0.0
## 発砲として流す区間（秒）。素材 1.167 秒は 1 発ぶんの反動で、実測では 0.130 秒まで
## 構えのまま静止し、0.42〜0.52 秒が反動の頂点、末尾で構えへ完全に戻る
## （先頭と末尾の姿勢が一致する）。前置きの静止だけを落とし、戻りは最後まで使う。
@export var pistol_fire_trim_start: float = 0.130
@export var pistol_fire_trim_end: float = 1.167
## 発砲を構えへ重ね始める／戻すときのフェード（秒）。
@export var pistol_fire_fade: float = 0.04
@export_file("*.gltf", "*.fbx") var pistol_walk_scene: String = \
	"res://assets/motions/mixamo_pistol_walk.fbx"
@export var pistol_walk_key: String = "mixamo_com"
## 銃歩行クリップの本来の移動速度（m/s。tools/measure_stride.gd の実測: 2.09）。
@export var pistol_walk_reference_speed: float = 2.09
## 走行素材を使わず、歩行クリップを実移動速度へ合わせる再生倍率の上限。
@export var pistol_walk_max_playback_scale: float = 2.2

@export_group("Katana Locomotion Clip")
@export_file("*.gltf", "*.fbx") var katana_idle_scene: String = \
	"res://assets/motions/mixamo_sword_idle.fbx"
@export var katana_idle_key: String = "mixamo_com"
## 停止時の剣待機から既存 locomotion へ完全に戻る速度（m/s）。
@export var katana_idle_blend_out_speed: float = 0.1

@export_group("Katana Combo Clips")
@export_file("*.gltf", "*.fbx") var katana_slash_scene: String = \
	"res://assets/motions/mixamo_sword_slash.fbx"
@export var katana_slash_key: String = "mixamo_com"
@export_file("*.gltf", "*.fbx") var katana_attack_scene: String = \
	"res://assets/motions/mixamo_melee_horizontal.fbx"
@export var katana_attack_key: String = "mixamo_com"
@export_file("*.gltf", "*.fbx") var katana_scene: String = \
	"res://assets/motions/mixamo_katana_360.fbx"
@export var katana_key: String = "mixamo_com"
## 刀の段間クロスフェード秒数。素手コンボの既定値と同じ。
@export var katana_combo_transition_xfade: float = 0.05

@export_group("One Shot Clips")
@export_file("*.gltf", "*.fbx") var dodge_scene: String = \
	"res://assets/motions/mixamo_dodge_backflip.fbx"
@export var dodge_key: String = "mixamo_com"
## 回避クリップから実際に再生する区間（秒。元クリップ 2.167 秒の中での位置）。
## Backflip 素材は前後に助走・構えと着地後の立ち上がりが付いており、そのまま流すと
## バク転以外の時間が長い。踏み切り直前から接地直後までだけを切り出す。
## 既定は元クリップ 30fps のボーン実測（踏み切り 0.667 秒 / 接地 1.333 秒 /
## 沈み込み解消 1.800 秒。tools/test_dodge_timing.gd）から、
## 開始は構えが一瞬入る 0.600 秒、終了は接地直後の 1.400 秒とする。
## FBX は編集せず、AnimationNodeAnimation の custom timeline で再生範囲だけを絞る。
@export var dodge_trim_start: float = 0.600
@export var dodge_trim_end: float = 1.400
## △必殺の素材は前置きの足踏みが長い。走り出しからだけを再生する。
@export var special_trim_start: float = 0.680
@export var special_trim_end: float = 3.700
@export_file("*.gltf", "*.fbx") var special_scene: String = \
	"res://assets/motions/mixamo_spin_flip_kick.fbx"
@export var special_key: String = "mixamo_com"
## 既存 locomotion と単発アクション間のクロスフェード秒数。
@export var action_transition_xfade: float = 0.05
@export_group("")

var _clip_lengths: Dictionary[StringName, float] = {}
## 切り出し前の素材の尺。_clip_lengths は切り出し後の長さを持つため別に控える。
var _source_lengths: Dictionary[StringName, float] = {}
var _available_actions: Array[StringName] = []
var _has_gun_locomotion: bool = false
var _has_gun_fire: bool = false
var _has_katana_idle: bool = false
## 発砲クリップのトラック一覧。OneShot を上半身だけに絞るフィルタで使う。
var _gun_fire_tracks: Array[NodePath] = []


## PlayerMelee の AnimationLibrary 構築中に呼ぶ。読めない素材は登録せず、
## 呼び出し側が旧モーションまたは従来のロジックだけの挙動へフォールバックする。
func add_clips(library: AnimationLibrary) -> void:
	_clip_lengths.clear()
	_source_lengths.clear()
	_available_actions.clear()
	_gun_fire_tracks.clear()
	_has_gun_locomotion = false
	_has_gun_fire = false
	_has_katana_idle = false

	var pistol_source: Animation = _extract(pistol_idle_scene, pistol_idle_key)
	var pistol_walk: Animation = _extract(pistol_walk_scene, pistol_walk_key)
	if pistol_source != null and pistol_walk != null:
		# 構えは動かさない。素材の1瞬だけを取り出し、キー1本ずつのクリップにする。
		var pistol_idle: Animation = _freeze_pose(pistol_source, pistol_idle_pose_time)
		pistol_idle.loop_mode = Animation.LOOP_LINEAR
		pistol_walk.loop_mode = Animation.LOOP_LINEAR
		RootMotion.lock_horizontal(pistol_idle)
		# In Place 版（水平移動の実測 0.000m）なので、歩行には水平固定を重ねない。
		library.add_animation(GUN_IDLE_ANIMATION, pistol_idle)
		library.add_animation(GUN_WALK_ANIMATION, pistol_walk)
		_source_lengths[GUN_IDLE_ANIMATION] = pistol_source.length
		_clip_lengths[GUN_IDLE_ANIMATION] = pistol_idle.length
		_clip_lengths[GUN_WALK_ANIMATION] = pistol_walk.length
		_has_gun_locomotion = true
		# 発砲は撃った瞬間だけ構えへ重ねる。素材は丸ごと持ち、区間はノード側で絞る。
		# 素材を編集しないので、切り出し位置は @export だけで調整できる。
		var pistol_fire: Animation = pistol_source.duplicate(true) as Animation
		pistol_fire.loop_mode = Animation.LOOP_NONE
		RootMotion.lock_horizontal(pistol_fire)
		library.add_animation(GUN_FIRE_ANIMATION, pistol_fire)
		for track: int in range(pistol_fire.get_track_count()):
			_gun_fire_tracks.append(pistol_fire.track_get_path(track))
		_source_lengths[GUN_FIRE_ANIMATION] = pistol_fire.length
		var fire_trim: Vector2 = _gun_fire_trim(pistol_fire.length)
		_clip_lengths[GUN_FIRE_ANIMATION] = fire_trim.y if fire_trim.y > 0.0 \
			else pistol_fire.length
		_has_gun_fire = true
	else:
		push_warning("player_action_anim: pistol locomotion load failed; default locomotion used")

	var sword_idle: Animation = _extract(katana_idle_scene, katana_idle_key)
	if sword_idle != null:
		sword_idle.loop_mode = Animation.LOOP_LINEAR
		# In Place 版（水平移動の実測 0.000m）なので水平固定は重ねない。
		library.add_animation(KATANA_IDLE_ANIMATION, sword_idle)
		_clip_lengths[KATANA_IDLE_ANIMATION] = sword_idle.length
		_has_katana_idle = true
	else:
		push_warning("player_action_anim: katana idle load failed; default idle used")

	_add_action_clip(library, ACTION_KATANA_1, katana_slash_scene, katana_slash_key)
	_add_action_clip(library, ACTION_KATANA_2, katana_attack_scene, katana_attack_key)
	_add_action_clip(library, ACTION_KATANA, katana_scene, katana_key)
	_add_action_clip(library, ACTION_DODGE, dodge_scene, dodge_key)
	_add_action_clip(library, ACTION_SPECIAL, special_scene, special_key)


## PlayerMelee の AnimationNodeStateMachine へアクションノードを追加する。
## 刀の段間だけはここで結び、locomotion 等との共通辺は PlayerMelee が追加する。
func add_states(state_machine: AnimationNodeStateMachine) -> void:
	var state_index: int = 0
	for action: StringName in ACTION_STATES:
		if not _available_actions.has(action):
			continue
		var state_position := Vector2(STATE_COLUMN_X + STATE_GAP_X * float(state_index),
			STATE_ROW_Y)
		state_machine.add_node(action, _make_action_state(action), state_position)
		state_index += 1
	_add_katana_transitions(state_machine)


func has_action(action: StringName) -> bool:
	return _available_actions.has(action)


func has_katana_combo() -> bool:
	return has_action(ACTION_KATANA_1) and has_action(ACTION_KATANA_2) \
		and has_action(ACTION_KATANA)


func action_states() -> Array[StringName]:
	return _available_actions.duplicate()


func has_gun_locomotion() -> bool:
	return _has_gun_locomotion


func has_gun_fire() -> bool:
	return _has_gun_fire


## 撃った瞬間に、静止した構えへ発砲の絵を一度だけ重ねる。locomotion のステートも
## 歩行のブレンドも変えないので、撃ちながら歩いてもステート遷移は起きない。
func play_gun_fire(tree: AnimationTree) -> void:
	if not _has_gun_fire or tree == null:
		return
	tree.set(GUN_FIRE_REQUEST_PARAMETER, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func has_katana_idle() -> bool:
	return _has_katana_idle


## 既存 locomotion の出力へ武器用ノードを Blend2 で重ねる。トップレベルの
## ステート名は変えず、dance・コンボ等が依存する locomotion 契約を保つ。
## 戻り値は最終出力ノード名。素材が読めなければ既存 speed をそのまま返す。
func add_weapon_locomotion(locomotion: AnimationNodeBlendTree,
		lower_body_bones: Array[String]) -> StringName:
	var output_node: StringName = &"speed"
	if _has_gun_locomotion:
		locomotion.add_node(GUN_LOCOMOTION_NODE, _make_gun_locomotion(lower_body_bones),
			Vector2(0.0, STATE_ROW_Y))
		locomotion.add_node(GUN_SELECT_NODE, AnimationNodeBlend2.new(),
			Vector2(STATE_GAP_X * 2.0, STATE_ROW_Y * 0.5))
		locomotion.connect_node(GUN_SELECT_NODE, 0, output_node)
		locomotion.connect_node(GUN_SELECT_NODE, 1, GUN_LOCOMOTION_NODE)
		output_node = GUN_SELECT_NODE
	if _has_katana_idle:
		var idle_node := AnimationNodeAnimation.new()
		idle_node.animation = StringName(PLAYER_LIBRARY_PREFIX + String(KATANA_IDLE_ANIMATION))
		idle_node.resource_name = "katana_idle"
		locomotion.add_node(KATANA_IDLE_NODE, idle_node,
			Vector2(STATE_GAP_X * 2.0, STATE_ROW_Y))
		locomotion.add_node(KATANA_SELECT_NODE, AnimationNodeBlend2.new(),
			Vector2(STATE_GAP_X * 3.0, STATE_ROW_Y * 0.5))
		locomotion.connect_node(KATANA_SELECT_NODE, 0, output_node)
		locomotion.connect_node(KATANA_SELECT_NODE, 1, KATANA_IDLE_NODE)
		output_node = KATANA_SELECT_NODE
	return output_node


func clip_length(animation_name: StringName) -> float:
	return float(_clip_lengths.get(animation_name, 0.0))


func configure_action(tree: AnimationTree, action: StringName, duration: float) -> void:
	if not has_action(action):
		return
	var speed_scale: float = 1.0
	var length: float = clip_length(action)
	if duration > 0.0 and length > 0.0:
		speed_scale = length / duration
	tree.set("parameters/main/%s/speed/scale" % String(action), speed_scale)
	tree.set("parameters/main/%s/seek/seek_request" % String(action), 0.0)


func configure_gun_locomotion(tree: AnimationTree, speed: float) -> void:
	if not _has_gun_locomotion:
		return
	var blend_position: float = 0.0
	if pistol_walk_reference_speed > MIN_NATURAL_SPEED:
		blend_position = clampf(speed / pistol_walk_reference_speed,
			0.0, GUN_WALK_BLEND_POSITION)
	tree.set(GUN_BLEND_POSITION_PARAMETER, blend_position)
	tree.set(GUN_SPEED_SCALE_PARAMETER, _gun_anim_speed_scale(speed))


func select_gun_locomotion(tree: AnimationTree, enabled: bool) -> void:
	if not _has_gun_locomotion:
		return
	tree.set(GUN_SELECT_PARAMETER, 1.0 if enabled else 0.0)


## 刀装備中だけ、停止時は剣待機、移動時は既存 idle/walk/jog を選ぶ。
func configure_katana_locomotion(tree: AnimationTree, speed: float) -> void:
	if not _has_katana_idle:
		return
	var blend_out_speed: float = maxf(katana_idle_blend_out_speed, MIN_NATURAL_SPEED)
	var blend_amount: float = 1.0 - clampf(speed / blend_out_speed, 0.0, 1.0)
	tree.set(KATANA_SELECT_PARAMETER, blend_amount)


func select_katana_locomotion(tree: AnimationTree, enabled: bool) -> void:
	if not _has_katana_idle:
		return
	tree.set(KATANA_SELECT_PARAMETER, 1.0 if enabled else 0.0)


func _add_action_clip(library: AnimationLibrary, action: StringName, scene_path: String,
		animation_key: String) -> void:
	var animation: Animation = _extract(scene_path, animation_key)
	if animation == null:
		push_warning("player_action_anim: %s (%s) load failed; caller fallback used" % [
			String(action), animation_key])
		return
	animation.loop_mode = Animation.LOOP_NONE
	RootMotion.lock_horizontal(animation)
	library.add_animation(action, animation)
	_source_lengths[action] = animation.length
	# 切り出す場合、ロジックが見る「クリップ長」は切り出した区間の長さにする。
	# configure_action() の再生倍率も、この長さと duration の比で決まる。
	var trim: Vector2 = _action_trim(action, animation.length)
	_clip_lengths[action] = trim.y if trim.y > 0.0 else animation.length
	_available_actions.append(action)


func _make_gun_locomotion(lower_body_bones: Array[String]) -> AnimationNodeBlendTree:
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 1.0
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = StringName(PLAYER_LIBRARY_PREFIX + String(GUN_IDLE_ANIMATION))
	idle_node.resource_name = "gun_idle"
	var walk_node := AnimationNodeAnimation.new()
	walk_node.animation = StringName(PLAYER_LIBRARY_PREFIX + String(GUN_WALK_ANIMATION))
	walk_node.resource_name = "gun_walk"
	blend.add_blend_point(idle_node, 0.0, -1, &"gun_idle")
	blend.add_blend_point(walk_node, GUN_WALK_BLEND_POSITION, -1, &"gun_walk")

	var locomotion := AnimationNodeBlendTree.new()
	locomotion.add_node("blend", blend, Vector2.ZERO)
	locomotion.add_node("speed", AnimationNodeTimeScale.new(), Vector2(STATE_GAP_X, 0.0))
	locomotion.connect_node("speed", 0, "blend")
	var output_source: StringName = &"speed"
	if _has_gun_fire:
		locomotion.add_node(GUN_FIRE_CLIP_NODE, _make_gun_fire_clip(),
			Vector2(0.0, STATE_ROW_Y))
		var one_shot := AnimationNodeOneShot.new()
		one_shot.fadein_time = pistol_fire_fade
		one_shot.fadeout_time = pistol_fire_fade
		_filter_to_upper_body(one_shot, lower_body_bones)
		locomotion.add_node(GUN_FIRE_NODE, one_shot, Vector2(STATE_GAP_X * 2.0, 0.0))
		locomotion.connect_node(GUN_FIRE_NODE, 0, output_source)
		locomotion.connect_node(GUN_FIRE_NODE, 1, GUN_FIRE_CLIP_NODE)
		output_source = GUN_FIRE_NODE
	locomotion.connect_node("output", 0, output_source)
	return locomotion


## 発砲を上半身のトラックだけに掛ける。素材は全身1本なので、絞らないと重なっている
## 約1秒のあいだ脚まで発砲クリップの立ち姿勢になり、撃った直後に歩いても銃持ち歩行の
## 絵にならない。下半身（lower_body_bones）は locomotion 側をそのまま通す。
## 被弾レイヤー（PlayerMelee の hurt_blend）と同じ作りにしてある。
func _filter_to_upper_body(node: AnimationNode, lower_body_bones: Array[String]) -> void:
	if _gun_fire_tracks.is_empty():
		return
	node.filter_enabled = true
	for path: NodePath in _gun_fire_tracks:
		var bone: String = String(path).get_slice(":", 1)
		if not lower_body_bones.has(bone):
			node.set_filter_path(path, true)


## 発砲1回ぶんのクリップノード。素材は編集せず、custom timeline で区間だけ絞る。
func _make_gun_fire_clip() -> AnimationNodeAnimation:
	var fire_clip := AnimationNodeAnimation.new()
	fire_clip.animation = StringName(PLAYER_LIBRARY_PREFIX + String(GUN_FIRE_ANIMATION))
	fire_clip.resource_name = "gun_fire"
	var trim: Vector2 = _gun_fire_trim(source_clip_length(GUN_FIRE_ANIMATION))
	if trim.y > 0.0:
		# stretch_time_scale は false にして、切り出した区間を等速のまま流す。
		fire_clip.use_custom_timeline = true
		fire_clip.start_offset = trim.x
		fire_clip.timeline_length = trim.y
		fire_clip.stretch_time_scale = false
	return fire_clip


## 発砲として流す区間（開始秒, 長さ秒）。指定が短すぎるときは全長を使う。
func _gun_fire_trim(source_length: float) -> Vector2:
	if source_length <= 0.0:
		return Vector2.ZERO
	var start: float = clampf(pistol_fire_trim_start, 0.0, source_length)
	var end: float = clampf(pistol_fire_trim_end, 0.0, source_length)
	if end - start < MIN_TRIM_LENGTH:
		return Vector2.ZERO
	return Vector2(start, end - start)


## 指定時刻の姿勢だけを取り出し、トラックごとにキー1本だけのクリップにする。
## 元のキーを間引くのではなく補間値を1つ置くので、区間のどこを再生しても動かない。
func _freeze_pose(source: Animation, time: float) -> Animation:
	var frozen := Animation.new()
	frozen.length = FROZEN_POSE_LENGTH
	var sample_time: float = clampf(time, 0.0, source.length)
	for track: int in range(source.get_track_count()):
		var track_type: int = source.track_get_type(track)
		var added: int = frozen.add_track(track_type)
		frozen.track_set_path(added, source.track_get_path(track))
		match track_type:
			Animation.TYPE_POSITION_3D:
				frozen.position_track_insert_key(added, 0.0,
					source.position_track_interpolate(track, sample_time))
			Animation.TYPE_ROTATION_3D:
				frozen.rotation_track_insert_key(added, 0.0,
					source.rotation_track_interpolate(track, sample_time))
			Animation.TYPE_SCALE_3D:
				frozen.scale_track_insert_key(added, 0.0,
					source.scale_track_interpolate(track, sample_time))
			_:
				# ボーン以外のトラックは構えに要らない。持ち込まない。
				frozen.remove_track(added)
	return frozen


## natural speed までは待機→歩行ブレンドを等速再生し、それを超える実移動速度は
## 歩行クリップの再生倍率へ反映する。CharacterBody3D の移動速度は変更しない。
func _gun_anim_speed_scale(speed: float) -> float:
	if speed < MIN_MOVING_SPEED:
		return 1.0
	if pistol_walk_reference_speed < MIN_NATURAL_SPEED:
		return 1.0
	var maximum_scale: float = maxf(pistol_walk_max_playback_scale, MIN_PLAYBACK_SCALE)
	return clampf(speed / pistol_walk_reference_speed,
		MIN_PLAYBACK_SCALE, maximum_scale)


## 切り出し区間（開始秒, 長さ秒）。切り出さないアクションは長さ 0 を返す。
func _action_trim(action: StringName, source_length: float) -> Vector2:
	if source_length <= 0.0:
		return Vector2.ZERO
	var start: float = 0.0
	var end: float = 0.0
	match action:
		ACTION_DODGE:
			start = dodge_trim_start
			end = dodge_trim_end
		ACTION_SPECIAL:
			start = special_trim_start
			end = special_trim_end
		_:
			return Vector2.ZERO
	start = clampf(start, 0.0, source_length)
	end = clampf(end, 0.0, source_length)
	if end - start < MIN_TRIM_LENGTH:
		return Vector2.ZERO
	return Vector2(start, end - start)


## 切り出し前の素材そのものの尺（秒）。検証・報告用。
func source_clip_length(action: StringName) -> float:
	return float(_source_lengths.get(action, 0.0))


## 切り出し区間（開始秒, 長さ秒）。切り出していなければ長さ 0。検証用。
func action_trim(action: StringName) -> Vector2:
	return _action_trim(action, source_clip_length(action))


func _make_action_state(action: StringName) -> AnimationNodeBlendTree:
	var animation_node := AnimationNodeAnimation.new()
	animation_node.animation = StringName(PLAYER_LIBRARY_PREFIX + String(action))
	var trim: Vector2 = _action_trim(action, source_clip_length(action))
	if trim.y > 0.0:
		# 素材の一部だけを再生する。stretch_time_scale は false にして、
		# 切り出した区間を等速のまま流す（true だと区間が引き伸ばされる）。
		animation_node.use_custom_timeline = true
		animation_node.start_offset = trim.x
		animation_node.timeline_length = trim.y
		animation_node.stretch_time_scale = false
	var action_tree := AnimationNodeBlendTree.new()
	action_tree.add_node("clip", animation_node, Vector2.ZERO)
	action_tree.add_node("seek", AnimationNodeTimeSeek.new(), Vector2(STATE_GAP_X, 0.0))
	action_tree.add_node("speed", AnimationNodeTimeScale.new(), Vector2(STATE_GAP_X * 2.0, 0.0))
	action_tree.connect_node("seek", 0, "clip")
	action_tree.connect_node("speed", 0, "seek")
	action_tree.connect_node("output", 0, "speed")
	return action_tree


## 刀の段間だけは PlayerActionAnim 内で辺を作る。PlayerMelee は既存の素手コンボツリーと
## locomotion/down の共通辺だけを所有し、刀の段構造を知らない。
func _add_katana_transitions(state_machine: AnimationNodeStateMachine) -> void:
	if not has_katana_combo():
		return
	_add_transition(state_machine, ACTION_KATANA_1, ACTION_KATANA_2,
		katana_combo_transition_xfade)
	_add_transition(state_machine, ACTION_KATANA_2, ACTION_KATANA,
		katana_combo_transition_xfade)


func _add_transition(state_machine: AnimationNodeStateMachine, from: StringName,
		to: StringName, xfade: float) -> void:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
	state_machine.add_transition(from, to, transition)


## FBX/gltf から指定名の Animation だけを取り出す。A_TPose 等の先頭クリップへは
## フォールバックしない。
func _extract(scene_path: String, animation_key: String) -> Animation:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	var source_player := _find(instance, "AnimationPlayer") as AnimationPlayer
	if source_player == null:
		instance.free()
		return null
	var result: Animation = null
	if source_player.has_animation(animation_key):
		result = source_player.get_animation(animation_key).duplicate(true) as Animation
	else:
		for animation_name: String in source_player.get_animation_list():
			if animation_name.ends_with("/" + animation_key):
				result = source_player.get_animation(animation_name).duplicate(true) as Animation
				break
	instance.free()
	return result


func _find(node: Node, class_name_to_find: String) -> Node:
	if node.get_class() == class_name_to_find:
		return node
	for child: Node in node.get_children():
		var found: Node = _find(child, class_name_to_find)
		if found != null:
			return found
	return null
