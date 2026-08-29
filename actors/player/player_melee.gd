extends Node

## プレイヤーのアニメーション制御。
## locomotion(idle/walk/run ブレンド)、dance、down/stand_up、入力列で分岐する近接コンボツリーを駆動する。
##
## AnimationTree のステートマシンをコード側で組み立てる（.tscn への手書きは誤りやすい）。
## - locomotion: idle/walk/run の BlendSpace1D + TimeScale（速度同期）
## - dance: FBX から読むループクリップ。locomotion とだけ相互遷移する
## - down/stand_up: それぞれ専用の非ループ FBX を正再生し、所要時間へ速度同期する
##   （stand_up の素材が無い場合だけ、従来どおり down を逆再生して代用する）
## - melee_1..3: 生成済み .res（単発クリップ + Call Method Track 付き）
##
## 入力の流れ（1 押し 1 発）:
##   attack()/kick() → locomotion なら対応するルートを開始。
##   各段の連鎖受付窓内の再押下だけを入力列として予約し、combo_tree.gd をたどる。
##   未定義入力は予約せず、その段までで locomotion に戻る。
##
## ゲームロジック（player.gd）→ このノード（AnimationTree駆動）の一方向依存のみ。
## Call Method Track が叩く _enable_hitbox / _disable_hitbox は player.gd 側に置く。

const MELEE_1_RES: String = "res://actors/player/anim/melee_1.res"
const MELEE_2_RES: String = "res://actors/player/anim/melee_2.res"
const MELEE_3_RES: String = "res://actors/player/anim/melee_3.res"
const KICK_1_RES: String = "res://actors/player/anim/kick_1.res"
const KICK_2_RES: String = "res://actors/player/anim/kick_2.res"
const KICK_3_RES: String = "res://actors/player/anim/kick_3.res"
const ComboTree := preload("res://actors/player/combo_tree.gd")
const PLAYER_ACTION_ANIM := preload("res://actors/player/player_action_anim.gd")

## 上半身だけに重ねるレイヤー（被弾リアクション・発砲の反動）が触らない下半身ボーン。
## コンボの踏み込み・ステップと、銃を持っての歩行を消さないため、これらのトラックは
## フィルタから外して常に本編（ステートマシン側・locomotion 側）を通す。
const LOWER_BODY_BONES: Array[String] = ["Root", "Hips",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]

## VRM をインスタンス化した Model ノード。
@export var model_path: NodePath = ^"../Model"
## 武器・追加アクションのクリップとステート生成を分担するノード。
@export var action_anim_path: NodePath = ^"../PlayerActionAnim"

@export_group("Locomotion Clips")
## 待機クリップ（Mixamo Idle）。
@export_file("*.gltf", "*.fbx") var idle_scene: String = "res://assets/motions/mixamo_idle.fbx"
@export var idle_key: String = "mixamo_com"
## 歩行クリップ。Medium Step Forward は In Place ではなく 0.93 m 前へ出るので、
## ループの継ぎ目で戻らないよう `RootMotion.lock_horizontal()` で水平成分を潰す。
## 差し替え候補は mixamo_walk / mixamo_walk_female / mixamo_walk_catwalk。
@export_file("*.gltf", "*.fbx") var walk_scene: String = "res://assets/motions/mixamo_step_forward.fbx"
@export var walk_key: String = "mixamo_com"
## 走行クリップ（Mixamo In Place）。
@export_file("*.gltf", "*.fbx") var run_scene: String = "res://assets/motions/mixamo_run.fbx"
@export var run_key: String = "mixamo_com"

@export_group("Dance Clip")
## 回復ダンス。locomotion と同様に FBX シーンとアニメーション名で読み込む。
@export_file("*.gltf", "*.fbx") var dance_scene: String = "res://assets/motions/mixamo_dance_headspin.fbx"
@export var dance_key: String = "mixamo_com"
## locomotion と dance 間のクロスフェード秒数。
@export var dance_transition_xfade: float = 0.15

@export_group("Down Clip")
## ダウン素材。倒れ込みで正再生する。
@export_file("*.gltf", "*.fbx") var down_scene: String = "res://assets/motions/mixamo_death_backward_01.fbx"
@export var down_key: String = "mixamo_com"
## 立ち上がり素材（Kip Up）。空にすると down を逆再生する従来の挙動へ戻る。
@export_file("*.gltf", "*.fbx") var stand_up_scene: String = "res://assets/motions/mixamo_kip_up.fbx"
@export var stand_up_key: String = "mixamo_com"

@export_group("Hurt Clip")
## 被弾リアクション。コンボを中断しないため、ステート遷移ではなく上半身だけの
## 重ねがけ（Blend2 レイヤー）で再生する。読めない素材なら被弾モーション無しで動く。
@export_file("*.gltf", "*.fbx") var hurt_scene: String = "res://assets/motions/mixamo_hit_react_small.fbx"
@export var hurt_key: String = "mixamo_com"
## 被弾リアクションを重ねる強さのピーク（0-1）。被弾直後が最大で、時間とともに 0 へ減衰する。
@export_range(0.0, 1.0) var hurt_blend_peak: float = 1.0
## 表示時間のこの割合まではピークを保ち、残りだけを滑らかに減衰させる。
@export_range(0.0, 0.9) var hurt_blend_hold_ratio: float = 0.55

@export_group("Locomotion Sync")
## locomotion ブレンドの基準速度（この速度で blend=1.0=走り）。
@export var locomotion_max_speed: float = 4.5
## 歩行クリップの本来の移動速度（m/s。tools/measure_stride.gd の実測: 1.53）。
@export var walk_natural_speed: float = 1.53
## 走行クリップの本来の移動速度（m/s。実測: 2.74）。
@export var run_natural_speed: float = 2.74
## アニメ再生速度スケールのクランプ範囲（足の周期を実速度へ寄せる際の上下限）。
@export var anim_speed_limits: Vector2 = Vector2(0.8, 1.8)

@export_group("Combo")
## 左ジャブをこの再生割合まで進めたら次段/待機へ抜ける
## （判定窓の終了 73% の直後）。
@export var jab_out_ratio: float = 0.85
## 右ストレートをこの再生割合まで進めたら次段/待機へ抜ける
## （判定窓の終了 81% の直後）。
@export var straight_out_ratio: float = 0.90
## 左フックの抜け割合（判定窓の終了 89% の直後）。
@export var hook_out_ratio: float = 0.95
## 右膝の抜け割合（判定窓の終了 74% の直後）。
@export var knee_out_ratio: float = 0.85
## 右ミドルの抜け割合（判定窓の終了 80% の直後）。
@export var middle_out_ratio: float = 0.90
## 右ハイの抜け割合（判定窓の終了 89% の直後）。
@export var high_out_ratio: float = 0.95
## 押下のデバウンス（物理フレーム数）。この間隔未満で届いた連続押下は
## 物理バウンス・パッドの二重イベントとして無視する（4f ≈ 66ms @60Hz）。
## 実時間でなく物理フレーム基準なのは、headless/ムービー実行でも決定的にするため。
## それ以外の受付窓内の押下は先行入力キューに積み、各段の終わりで消化する。
@export var press_debounce_frames: int = 4
## locomotion から初段へ入るクロスフェード秒数。
@export var combo_start_xfade: float = 0.08
## 技から次の技へ繋ぐクロスフェード秒数。
@export var combo_transition_xfade: float = 0.05
## 技から locomotion へ戻るクロスフェード秒数。
@export var combo_exit_xfade: float = 0.20
## 段終了後、locomotion 中でも直前ノードから次段へ繋げられる猶予時間。
@export var combo_grace_time: float = 0.40
@export_group("")

signal combo_started()
signal combo_finished()
## フィニッシュ技（hook/high）へ到達せず、入力列が尽きてコンボが終了した。
signal combo_interrupted()
signal dance_started()
signal dance_finished()
signal down_animation_started()
signal stand_up_animation_started()
signal down_animation_finished()

var _anim_player: AnimationPlayer = null
var _tree: AnimationTree = null
var _state_machine: AnimationNodeStateMachinePlayback = null
var _model: Node3D = null
var _action_anim: PLAYER_ACTION_ANIM = null
var _active_action: StringName = &""
var _action_time_left: float = 0.0
## true は従来の単発技を内部タイマーで終了、false は刀コンボ側の段タイマーで終了する。
var _action_auto_finish: bool = true
var _gun_locomotion_enabled: bool = false
var _katana_locomotion_enabled: bool = false
var _locomotion_speed: float = 0.0
var _down_clip_length: float = 0.0
## 立ち上がりクリップの長さ。専用素材が無いときは down と同じ値。
var _stand_up_clip_length: float = 0.0
## 専用の立ち上がりクリップを読めたか。読めなければ down の逆再生で代用する。
var _has_stand_up_clip: bool = false
## 被弾リアクションを読めたか。読めなければレイヤーを組まず従来どおり動く。
var _has_hurt_clip: bool = false
var _hurt_clip_length: float = 0.0
## 被弾レイヤーの残り秒数と今回の全体秒数。残りが 0 でレイヤーは見えなくなる。
var _hurt_time_left: float = 0.0
var _hurt_duration: float = 0.0

var _state: String = "locomotion"
var _combo_node: StringName = &""
var _combo_stage: int = 0
var _grace_node: StringName = &""
var _grace_stage: int = 0
var _grace_time_left: float = 0.0
var _grace_ended_with_finisher: bool = false
## 先行入力列。追加時に木を投影して、存在する遷移だけを保持する。
var _queued_inputs: Array[StringName] = []
## 未定義入力を受けたら閉じ、同じコンボ中の後続入力も保持しない。
var _queue_closed: bool = false
var _last_press_frame: int = -1000
var _last_kick_frame: int = -1000

## コンボの段が始まった（technique: jab/straight/hook/knee/middle/high）。
## stage はルート内の1始まり段数で、踏み込み倍率等の駆動に使う。
signal stage_started(technique: StringName, stage: int)


func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	_action_anim = get_node_or_null(action_anim_path) as PLAYER_ACTION_ANIM
	if _model == null:
		push_warning("player_melee: Model not found")
		return
	var skeleton := _find(_model, "Skeleton3D") as Skeleton3D
	if skeleton != null:
		skeleton.unique_name_in_owner = true
	_anim_player = _find(_model, "AnimationPlayer") as AnimationPlayer
	if _anim_player == null:
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_model.add_child(_anim_player)
	_anim_player.root_node = _anim_player.get_path_to(_model)

	if not _build_library():
		return
	_build_tree()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _state_machine == null:
		return
	if _grace_time_left > 0.0:
		_grace_time_left = maxf(_grace_time_left - delta, 0.0)
		if _grace_time_left <= 0.0:
			_discard_combo_grace(true)
	# 被弾レイヤーの減衰。コンボ処理とは独立に、どのステートでも毎フレーム進める。
	if _hurt_time_left > 0.0:
		_hurt_time_left = maxf(_hurt_time_left - delta, 0.0)
		var elapsed_ratio: float = 1.0 - _hurt_time_left / _hurt_duration
		var blend_ratio: float = 1.0
		if elapsed_ratio > hurt_blend_hold_ratio:
			var fade_progress: float = (elapsed_ratio - hurt_blend_hold_ratio) \
				/ (1.0 - hurt_blend_hold_ratio)
			blend_ratio = 1.0 - smoothstep(0.0, 1.0, fade_progress)
		_tree.set("parameters/hurt_blend/blend_amount",
			hurt_blend_peak * blend_ratio)
	if _active_action != &"":
		if _action_auto_finish:
			_action_time_left = maxf(_action_time_left - delta, 0.0)
			if _action_time_left <= 0.0:
				_finish_action_animation()
		return
	if _state == "locomotion" or _state == "dance" or _state == "down" \
			or _state == "stand_up":
		return
	# クリップ終端の検出は再生位置で行う（自動遷移に任せず、入力列の分岐をコードで握る）。
	var technique := ComboTree.technique_for(_combo_node)
	if not _reached_ratio(_state, _out_ratio_for(technique)):
		return
	if _queued_inputs.is_empty():
		_finish_combo()
		return
	var input_kind: StringName = _queued_inputs.pop_front()
	var next_node := ComboTree.next_node(_combo_node, input_kind)
	if next_node == &"":
		_finish_combo()
		return
	_advance_to(next_node)


## キューを消化して次段へ進む。
func _advance_to(next_node: StringName) -> void:
	_combo_node = next_node
	_combo_stage += 1
	var technique := ComboTree.technique_for(_combo_node)
	_state = String(ComboTree.state_for_technique(technique))
	_state_machine.travel(_state)
	stage_started.emit(technique, _combo_stage)


## 現在ステートのクリップが指定割合まで再生されたか。
func _reached_ratio(state_name: String, ratio: float) -> bool:
	if str(_state_machine.get_current_node()) != state_name:
		return false
	var length := _state_machine.get_current_length()
	var pos := _state_machine.get_current_play_position()
	return length > 0.0 and pos >= length * ratio


func _out_ratio_for(technique: StringName) -> float:
	match technique:
		ComboTree.TECHNIQUE_JAB:
			return jab_out_ratio
		ComboTree.TECHNIQUE_STRAIGHT:
			return straight_out_ratio
		ComboTree.TECHNIQUE_HOOK:
			return hook_out_ratio
		ComboTree.TECHNIQUE_KNEE:
			return knee_out_ratio
		ComboTree.TECHNIQUE_MIDDLE:
			return middle_out_ratio
		ComboTree.TECHNIQUE_HIGH:
			return high_out_ratio
	return 1.0


## player.gd の locomotion 更新。速度に応じて idle(0)→walk(0.5)→jog(1.0) をブレンド。
func set_locomotion(speed: float) -> void:
	if _tree == null:
		return
	_locomotion_speed = speed
	var blend := clampf(speed / locomotion_max_speed, 0.0, 1.0)
	_tree.set("parameters/main/locomotion/blend/blend_position", blend)
	# アニメ再生速度を地面速度に同期する。ブレンド位置に対応する
	# クリップ本来の速度 (natural) で実速度を割った値が再生スケール。
	# blend<=0.5 (idle↔walk) では natural も blend に比例するため一定値に収束し、
	# 停止直前に再生スケールが暴れない。
	_tree.set("parameters/main/locomotion/speed/scale", _anim_speed_scale(speed, blend))
	if _action_anim != null and _gun_locomotion_enabled:
		_action_anim.configure_gun_locomotion(_tree, speed)
	if _action_anim != null and _katana_locomotion_enabled:
		_action_anim.configure_katana_locomotion(_tree, speed)


## 実移動速度とブレンド位置からアニメ再生スケールを求める。
func _anim_speed_scale(speed: float, blend: float) -> float:
	if speed < 0.1 or blend < 0.01:
		return 1.0
	var natural: float
	if blend <= 0.5:
		# idle(0) → walk(0.5): natural は歩行速度へ比例で立ち上がる。
		natural = walk_natural_speed * (blend / 0.5)
	else:
		natural = lerpf(walk_natural_speed, run_natural_speed, (blend - 0.5) / 0.5)
	if natural < 0.01:
		return 1.0
	return clampf(speed / natural, anim_speed_limits.x, anim_speed_limits.y)


## 攻撃入力（押下イベント 1 回につき 1 コール。押しっぱなしでは再コールされない）。
## - デバウンス: 前回受理した押下から press_debounce_frames 未満の押下は
##   物理バウンス/二重イベントとして無視（1 押し 1 発の保証）
## - locomotion: P ルートを開始。この押下はここで消費され、連鎖には使われない
## - コンボ中: 木に存在する P 遷移だけを先行入力キューへ積む
func attack() -> void:
	if _state_machine == null:
		return
	var now := Engine.get_physics_frames()
	if now - _last_press_frame < press_debounce_frames:
		return
	_last_press_frame = now
	_accept_input(ComboTree.INPUT_PUNCH)


## キック入力。attack() と同じキュー/デバウンス方式で K 遷移を選ぶ。
func kick() -> void:
	if _state_machine == null:
		return
	var now := Engine.get_physics_frames()
	if now - _last_kick_frame < press_debounce_frames:
		return
	_last_kick_frame = now
	_accept_input(ComboTree.INPUT_KICK)


func _accept_input(input_kind: StringName) -> void:
	if _state == "locomotion":
		if _grace_time_left > 0.0 and _grace_node != &"":
			var grace_next := ComboTree.next_node(_grace_node, input_kind)
			if grace_next != &"":
				_resume_from_grace(grace_next)
				return
			_discard_combo_grace(true)
		_start_combo(ComboTree.root_for(input_kind))
		return
	if _state == "dance":
		return
	if _queue_closed:
		return
	# 抜け割合を過ぎた入力は、同じ物理フレームで終端処理より先に届いても予約しない。
	var technique := ComboTree.technique_for(_combo_node)
	if _reached_ratio(_state, _out_ratio_for(technique)):
		_queue_closed = true
		return
	var projected_node := _projected_node()
	var next_node := ComboTree.next_node(projected_node, input_kind)
	if next_node == &"":
		# ルート外入力が来た時点でこのコンボの入力受付を閉じる。
		_queue_closed = true
		return
	_queued_inputs.append(input_kind)


func _start_combo(root_node: StringName) -> void:
	if root_node == &"":
		return
	_discard_combo_grace(false)
	_combo_node = root_node
	_combo_stage = 1
	_queued_inputs.clear()
	_queue_closed = false
	var technique := ComboTree.technique_for(_combo_node)
	_state = String(ComboTree.state_for_technique(technique))
	_state_machine.travel(_state)
	combo_started.emit()
	stage_started.emit(technique, _combo_stage)


func _projected_node() -> StringName:
	var projected := _combo_node
	for input_kind in _queued_inputs:
		projected = ComboTree.next_node(projected, input_kind)
		if projected == &"":
			break
	return projected


## 現在のコンボノード（`ComboTree.NODES` のキー）。コンボ中でなければ空。
## HUD が「次に何が繋がるか」を引くために公開する。
func combo_node() -> StringName:
	return _combo_node


func is_attacking() -> bool:
	return _combo_node != &"" or _active_action != &""


## 武器・追加アクションの全身単発モーションを要求する。素材が読めない場合は
## true を返してロジックのみの従来挙動を許可し、他の全身モーション中だけ拒否する。
func request_action(action: StringName, duration: float) -> bool:
	if _action_anim == null or not _action_anim.has_action(action):
		return true
	if _state_machine == null or _state != "locomotion" or _active_action != &"":
		return false
	_discard_combo_grace(true)
	_active_action = action
	_action_time_left = maxf(duration, 0.0)
	_action_auto_finish = true
	_state = String(action)
	_action_anim.configure_action(_tree, action, duration)
	_state_machine.travel(action)
	return true


## 刀コンボの初段。入口条件は通常の全身アクションと同じだが、終了時刻は
## 段ごとの判定を持つ PlayerKatanaCombo に委ねる。
func request_combo_action(action: StringName, duration: float) -> bool:
	if not request_action(action, duration):
		return false
	if _action_anim != null and _action_anim.has_action(action):
		_action_auto_finish = false
	return true


## 進行中の全身アクションから、同じ入力列の次段へ遷移する。通常の request_action()
## より許可範囲を広げるのはこの明示APIだけで、素手コンボや他アクションの入口は変えない。
func continue_action(action: StringName, duration: float) -> bool:
	if _action_anim == null or not _action_anim.has_action(action):
		return true
	if _state_machine == null or _active_action == &"":
		return false
	_active_action = action
	_action_time_left = maxf(duration, 0.0)
	_action_auto_finish = false
	_state = String(action)
	_action_anim.configure_action(_tree, action, duration)
	_state_machine.travel(action)
	return true


## アクション側タイマーが終了したときだけ locomotion へ戻す。別アクションや
## down/stand_up へ既に遷移していれば何もしない。
func finish_action(action: StringName) -> void:
	if _active_action != action:
		return
	_finish_action_animation()


func has_action_motion(action: StringName) -> bool:
	return _action_anim != null and _action_anim.has_action(action)


func is_action_playing() -> bool:
	return _active_action != &""


func action_clip_length(action: StringName) -> float:
	if _action_anim == null:
		return 0.0
	return _action_anim.clip_length(action)


## 銃装備時だけ専用の待機・移動ブレンドへ切り替える。素材が読めない場合は
## false 扱いとなり、既存 locomotion のまま続行する。
func set_gun_locomotion(enabled: bool) -> void:
	_gun_locomotion_enabled = enabled and _action_anim != null \
		and _action_anim.has_gun_locomotion()
	if _tree != null and _action_anim != null:
		_action_anim.select_gun_locomotion(_tree, _gun_locomotion_enabled)


func has_gun_locomotion() -> bool:
	return _action_anim != null and _action_anim.has_gun_locomotion()


## 撃った瞬間の絵を構えへ一度だけ重ねる。ステートも歩行のブレンドも変えないので、
## 撃ちながら歩いても locomotion の進行には触らない。
func play_gun_fire() -> void:
	if _tree == null or _action_anim == null:
		return
	_action_anim.play_gun_fire(_tree)


func has_gun_fire() -> bool:
	return _action_anim != null and _action_anim.has_gun_fire()


## 刀装備時だけ停止ポーズを剣待機へ切り替える。移動時は既存 locomotion を使う。
func set_katana_locomotion(enabled: bool) -> void:
	_katana_locomotion_enabled = enabled and _action_anim != null \
		and _action_anim.has_katana_idle()
	if _tree != null and _action_anim != null:
		if _katana_locomotion_enabled:
			_action_anim.configure_katana_locomotion(_tree, _locomotion_speed)
		else:
			_action_anim.select_katana_locomotion(_tree, false)


func has_katana_locomotion() -> bool:
	return _action_anim != null and _action_anim.has_katana_idle()


func gun_clip_length(animation_name: StringName) -> float:
	if _action_anim == null:
		return 0.0
	return _action_anim.clip_length(animation_name)


## locomotion からだけダンスへ入る。攻撃中など他ステートからは遷移しない。
func start_dance() -> bool:
	if _state_machine == null or _state != "locomotion":
		return false
	_discard_combo_grace(true)
	_state = "dance"
	_state_machine.travel("dance")
	dance_started.emit()
	return true


## ダンス中だけ locomotion へ戻す。コンボの入力列には触れない。
func stop_dance() -> void:
	if _state_machine == null or _state != "dance":
		return
	_state = "locomotion"
	_travel_locomotion()
	dance_finished.emit()


func is_dancing() -> bool:
	return _state == "dance"


## 被弾リアクションを上半身レイヤーで重ねる（player.gd の受け筋から呼ばれる）。
## 進行中のコンボ状態・先行入力キュー・攻撃判定・ステート進行には一切触れない。
## クリップは頭から duration 秒に収まる速度で再生し、重ねは duration 秒で 0 へ減衰する。
func play_hurt(duration: float) -> void:
	if _tree == null or not _has_hurt_clip or duration <= 0.0:
		return
	# 倒れ込み・立ち上がりには重ねない（全身クリップの姿勢を崩すだけになる）。
	if _state == "down" or _state == "stand_up":
		return
	# 上半身リアクションは進行中のコンボを止めないが、待機中の猶予は破棄する。
	_discard_combo_grace(false)
	_hurt_duration = duration
	_hurt_time_left = duration
	_tree.set("parameters/hurt_speed/scale", _scale_for(_hurt_clip_length, duration))
	_tree.set("parameters/hurt_blend/blend_amount", hurt_blend_peak)
	_tree.set("parameters/hurt_seek/seek_request", 0.0)


## プレイヤーのダウン開始。現在の行動を破棄し、非ループクリップを正再生する。
func start_down(fall_time: float) -> void:
	if _state_machine == null:
		return
	_lock_registered_horizontal(&"player/down")
	var was_attacking: bool = _combo_node != &""
	var was_dancing: bool = _state == "dance"
	_reset_combo_state()
	_cancel_action_animation()
	if was_attacking:
		combo_finished.emit()
	if was_dancing:
		dance_finished.emit()
	_state = "down"
	# 倒れ込みに被弾リアクションを重ねない。レイヤーは即座に消す。
	_hurt_time_left = 0.0
	if _has_hurt_clip:
		_tree.set("parameters/hurt_blend/blend_amount", 0.0)
	_tree.set("parameters/main/down/speed/scale", _duration_scale(fall_time))
	_state_machine.travel("down")
	down_animation_started.emit()


## 倒れた姿勢から立ち上がる。専用クリップがあれば正再生、無ければ down の逆再生。
func start_stand_up(stand_time: float) -> void:
	if _state_machine == null or _state != "down":
		return
	_lock_registered_horizontal(&"player/stand_up")
	_state = "stand_up"
	_tree.set("parameters/main/stand_up/speed/scale",
		_scale_for(_stand_up_clip_length, stand_time))
	_state_machine.travel("stand_up")
	stand_up_animation_started.emit()


## 立ち上がり完了後に locomotion へ戻す。
func finish_down() -> void:
	if _state_machine == null:
		return
	_state = "locomotion"
	_travel_locomotion()
	down_animation_finished.emit()


func _duration_scale(duration: float) -> float:
	return _scale_for(_down_clip_length, duration)


func _scale_for(clip_length: float, duration: float) -> float:
	if duration <= 0.0 or clip_length <= 0.0:
		return 1.0
	return clip_length / duration


## 登録済みの最終 Animation を固定する。ビルド時の複製後にライブラリが差し替わっても、
## ダウン／立ち上がりの再生直前に水平ルートモーションが残らないようにする。
func _lock_registered_horizontal(animation_name: StringName) -> void:
	if _anim_player == null or not _anim_player.has_animation(animation_name):
		return
	RootMotion.lock_horizontal(_anim_player.get_animation(animation_name))


## AnimationTree が実際に使う登録済みクリップの最大水平移動量（m）。headless 検証用。
func registered_horizontal_drift(animation_name: StringName) -> float:
	if _anim_player == null or not _anim_player.has_animation(animation_name):
		return -1.0
	return RootMotion.horizontal_max_drift(_anim_player.get_animation(animation_name))


func _finish_action_animation() -> void:
	_active_action = &""
	_action_time_left = 0.0
	_action_auto_finish = true
	_state = "locomotion"
	_travel_locomotion()


func _cancel_action_animation() -> void:
	_active_action = &""
	_action_time_left = 0.0
	_action_auto_finish = true


func _travel_locomotion() -> void:
	if _state_machine == null:
		return
	_state_machine.travel(&"locomotion")


func _finish_combo() -> void:
	var technique := ComboTree.technique_for(_combo_node)
	var ended_with_finisher: bool = technique == ComboTree.TECHNIQUE_HOOK \
		or technique == ComboTree.TECHNIQUE_HIGH
	var finished_node: StringName = _combo_node
	var finished_stage: int = _combo_stage
	var can_continue: bool = ComboTree.next_node(finished_node, ComboTree.INPUT_PUNCH) != &"" \
		or ComboTree.next_node(finished_node, ComboTree.INPUT_KICK) != &""
	_state = "locomotion"
	_clear_active_combo()
	_travel_locomotion()
	if can_continue and combo_grace_time > 0.0:
		_grace_node = finished_node
		_grace_stage = finished_stage
		_grace_time_left = combo_grace_time
		_grace_ended_with_finisher = ended_with_finisher
	elif not ended_with_finisher:
		combo_interrupted.emit()
	combo_finished.emit()


func _reset_combo_state() -> void:
	_clear_active_combo()
	_discard_combo_grace(false)


func _clear_active_combo() -> void:
	_combo_node = &""
	_combo_stage = 0
	_queued_inputs.clear()
	_queue_closed = false


func _resume_from_grace(next_node: StringName) -> void:
	_combo_node = _grace_node
	_combo_stage = _grace_stage
	_discard_combo_grace(false)
	_queued_inputs.clear()
	_queue_closed = false
	_advance_to(next_node)


func _discard_combo_grace(emit_interruption: bool) -> void:
	var should_emit: bool = emit_interruption and _grace_node != &"" \
		and not _grace_ended_with_finisher
	_grace_node = &""
	_grace_stage = 0
	_grace_time_left = 0.0
	_grace_ended_with_finisher = false
	if should_emit:
		combo_interrupted.emit()


func _build_library() -> bool:
	var lib := AnimationLibrary.new()

	var idle := _extract(idle_scene, idle_key)
	if idle == null:
		push_warning("player_melee: idle (%s) load failed" % idle_key)
		return false
	idle.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("idle", idle)

	var walk := _extract(walk_scene, walk_key)
	if walk != null:
		walk.loop_mode = Animation.LOOP_LINEAR
		RootMotion.lock_horizontal(walk)
		lib.add_animation("walk", walk)
	else:
		push_warning("player_melee: walk (%s) load failed。idle で代用" % walk_key)
		lib.add_animation("walk", idle.duplicate(true) as Animation)

	var jog := _extract(run_scene, run_key)
	if jog != null:
		jog.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("jog", jog)
	else:
		push_warning("player_melee: run (%s) load failed。idle で代用" % run_key)
		lib.add_animation("jog", idle.duplicate(true) as Animation)

	var dance := _extract(dance_scene, dance_key)
	if dance == null:
		push_warning("player_melee: dance (%s) load failed" % dance_key)
		return false
	dance.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("dance", dance)

	var down := _extract(down_scene, down_key)
	if down == null:
		push_warning("player_melee: down (%s) load failed" % down_key)
		return false
	down.loop_mode = Animation.LOOP_NONE
	RootMotion.lock_horizontal(down)
	_down_clip_length = down.length
	lib.add_animation("down", down)

	# 立ち上がりは専用クリップを優先する。読めなければ down の逆再生で代用し、
	# 素材が無い環境でも従来どおり動くようにする。
	var stand_up: Animation = null
	if not stand_up_scene.is_empty():
		stand_up = _extract(stand_up_scene, stand_up_key)
	_has_stand_up_clip = stand_up != null
	if _has_stand_up_clip:
		stand_up.loop_mode = Animation.LOOP_NONE
		RootMotion.lock_horizontal(stand_up)
		_stand_up_clip_length = stand_up.length
		lib.add_animation("stand_up", stand_up)
	else:
		if not stand_up_scene.is_empty():
			push_warning("player_melee: stand_up (%s) load failed。down の逆再生で代用"
				% stand_up_key)
		_stand_up_clip_length = _down_clip_length

	# 被弾リアクション。読めなくても致命ではないので、レイヤー無しで続行する。
	var hurt: Animation = null
	if not hurt_scene.is_empty():
		hurt = _extract(hurt_scene, hurt_key)
	_has_hurt_clip = hurt != null
	if _has_hurt_clip:
		hurt.loop_mode = Animation.LOOP_NONE
		RootMotion.lock_horizontal(hurt)
		_hurt_clip_length = hurt.length
		lib.add_animation("hurt", hurt)
	elif not hurt_scene.is_empty():
		push_warning("player_melee: hurt (%s) load failed。被弾モーション無しで続行" % hurt_key)

	var m1 := load(MELEE_1_RES) as Animation
	var m2 := load(MELEE_2_RES) as Animation
	var m3 := load(MELEE_3_RES) as Animation
	var k1 := load(KICK_1_RES) as Animation
	var k2 := load(KICK_2_RES) as Animation
	var k3 := load(KICK_3_RES) as Animation
	if m1 == null or m2 == null or m3 == null or k1 == null or k2 == null or k3 == null:
		push_warning("player_melee: melee/kick .res load failed（build_melee_anims.gd を先に実行）")
		return false
	lib.add_animation("melee_1", m1)
	lib.add_animation("melee_2", m2)
	lib.add_animation("melee_3", m3)
	lib.add_animation("kick_1", k1)
	lib.add_animation("kick_2", k2)
	lib.add_animation("kick_3", k3)
	if _action_anim != null:
		_action_anim.add_clips(lib)

	if _anim_player.has_animation_library("player"):
		_anim_player.remove_animation_library("player")
	_anim_player.add_animation_library("player", lib)
	return true


## FBX/gltf から 1 本の Animation を取り出す。見つからなければ null
## （以前の「先頭クリップへのフォールバック」は A_TPose を拾う事故の原因だったため廃止）。
func _extract(scene_path: String, key: String) -> Animation:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var src := _find(inst, "AnimationPlayer") as AnimationPlayer
	if src == null:
		inst.free()
		return null
	var result: Animation = null
	if src.has_animation(key):
		result = src.get_animation(key).duplicate(true) as Animation
	else:
		# ライブラリ接頭辞付き（"lib/Key"）で探す。
		for a in src.get_animation_list():
			if str(a).ends_with("/" + key):
				result = src.get_animation(a).duplicate(true) as Animation
				break
	inst.free()
	return result


func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()

	# locomotion: idle(0.0) / walk(0.5) / run(1.0) の BlendSpace1D（速度でブレンド）を
	# TimeScale ノード付きの BlendTree に包み、足の周期を実移動速度へ同期できるようにする。
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 1.0
	var n_idle := AnimationNodeAnimation.new()
	n_idle.animation = "player/idle"
	n_idle.resource_name = "idle"
	var n_walk := AnimationNodeAnimation.new()
	n_walk.animation = "player/walk"
	n_walk.resource_name = "walk"
	var n_jog := AnimationNodeAnimation.new()
	n_jog.animation = "player/jog"
	n_jog.resource_name = "run"
	blend.add_blend_point(n_idle, 0.0, -1, &"idle")
	blend.add_blend_point(n_walk, 0.5, -1, &"walk")
	blend.add_blend_point(n_jog, 1.0, -1, &"run")

	var loco := AnimationNodeBlendTree.new()
	loco.add_node("blend", blend, Vector2(0, 0))
	loco.add_node("speed", AnimationNodeTimeScale.new(), Vector2(250, 0))
	loco.connect_node("speed", 0, "blend")
	var locomotion_output: StringName = &"speed"
	if _action_anim != null:
		locomotion_output = _action_anim.add_weapon_locomotion(loco, LOWER_BODY_BONES)
	loco.connect_node("output", 0, locomotion_output)

	var n_m1 := AnimationNodeAnimation.new()
	n_m1.animation = "player/melee_1"
	var n_m2 := AnimationNodeAnimation.new()
	n_m2.animation = "player/melee_2"
	var n_m3 := AnimationNodeAnimation.new()
	n_m3.animation = "player/melee_3"
	var n_k1 := AnimationNodeAnimation.new()
	n_k1.animation = "player/kick_1"
	var n_k2 := AnimationNodeAnimation.new()
	n_k2.animation = "player/kick_2"
	var n_k3 := AnimationNodeAnimation.new()
	n_k3.animation = "player/kick_3"
	var n_dance := AnimationNodeAnimation.new()
	n_dance.animation = "player/dance"
	var n_down := AnimationNodeAnimation.new()
	n_down.animation = "player/down"
	var n_stand_up := AnimationNodeAnimation.new()
	if _has_stand_up_clip:
		n_stand_up.animation = "player/stand_up"
	else:
		n_stand_up.animation = "player/down"
		n_stand_up.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD

	var down_tree := AnimationNodeBlendTree.new()
	down_tree.add_node("clip", n_down, Vector2(0, 0))
	down_tree.add_node("speed", AnimationNodeTimeScale.new(), Vector2(250, 0))
	down_tree.connect_node("speed", 0, "clip")
	down_tree.connect_node("output", 0, "speed")

	var stand_up_tree := AnimationNodeBlendTree.new()
	stand_up_tree.add_node("clip", n_stand_up, Vector2(0, 0))
	stand_up_tree.add_node("speed", AnimationNodeTimeScale.new(), Vector2(250, 0))
	stand_up_tree.connect_node("speed", 0, "clip")
	stand_up_tree.connect_node("output", 0, "speed")

	sm.add_node("locomotion", loco, Vector2(0, 0))
	sm.add_node("melee_1", n_m1, Vector2(300, 0))
	sm.add_node("melee_2", n_m2, Vector2(600, 0))
	sm.add_node("melee_3", n_m3, Vector2(900, 0))
	sm.add_node("kick_1", n_k1, Vector2(300, 150))
	sm.add_node("kick_2", n_k2, Vector2(600, 150))
	sm.add_node("kick_3", n_k3, Vector2(900, 150))
	sm.add_node("dance", n_dance, Vector2(0, -180))
	sm.add_node("down", down_tree, Vector2(300, -180))
	sm.add_node("stand_up", stand_up_tree, Vector2(600, -180))
	if _action_anim != null:
		_action_anim.add_states(sm)

	# 全遷移をコード駆動（即時）にする。技間の辺はコンボツリーから導出し、
	# ルートを変更したとき AnimationTree 側に遷移を追記しなくてよいようにする。
	var transition_keys: Dictionary = {}
	for root_input in [ComboTree.INPUT_PUNCH, ComboTree.INPUT_KICK]:
		var root_node := ComboTree.root_for(root_input)
		_add_transition_once(sm, &"locomotion", ComboTree.state_for_node(root_node),
			combo_start_xfade, transition_keys)
	for node_key in ComboTree.NODES:
		var node_id := StringName(node_key)
		var from_state := ComboTree.state_for_node(node_id)
		for input_kind in [ComboTree.INPUT_PUNCH, ComboTree.INPUT_KICK]:
			var next_node := ComboTree.next_node(node_id, input_kind)
			if next_node == &"":
				continue
			_add_transition_once(sm, from_state, ComboTree.state_for_node(next_node),
				combo_transition_xfade, transition_keys)
	for technique in ComboTree.TECHNIQUES:
		_add_transition_once(sm, ComboTree.state_for_technique(technique), &"locomotion",
			combo_exit_xfade, transition_keys)
	_add_transition_once(sm, &"locomotion", &"dance", dance_transition_xfade, transition_keys)
	_add_transition_once(sm, &"dance", &"locomotion", dance_transition_xfade, transition_keys)
	if _action_anim != null:
		for action_state: StringName in _action_anim.action_states():
			_add_transition_once(sm, &"locomotion", action_state,
				_action_anim.action_transition_xfade, transition_keys)
			_add_transition_once(sm, action_state, &"locomotion",
				_action_anim.action_transition_xfade, transition_keys)
	# ダウンはどの行動中にも割り込み、立ち上がり後に待機へ戻る。
	var down_sources: Array[StringName] = [&"locomotion", &"dance", &"melee_1", &"melee_2",
		&"melee_3", &"kick_1", &"kick_2", &"kick_3"]
	if _action_anim != null:
		down_sources.append_array(_action_anim.action_states())
	for state_name: StringName in down_sources:
		_add_transition_once(sm, state_name, &"down", 0.0, transition_keys)
	_add_transition_once(sm, &"down", &"stand_up", 0.0, transition_keys)
	_add_transition_once(sm, &"stand_up", &"locomotion", 0.0, transition_keys)

	# ステートマシンを "main" として BlendTree に包み、被弾リアクションの
	# 上半身レイヤー（hurt → seek → speed → Blend2）を重ねられるようにする。
	# ステート遷移で被弾を表現するとコンボが中断されるため、遷移には触れない。
	var root := AnimationNodeBlendTree.new()
	root.add_node("main", sm, Vector2(0, 0))
	if _has_hurt_clip:
		var n_hurt := AnimationNodeAnimation.new()
		n_hurt.animation = "player/hurt"
		root.add_node("hurt", n_hurt, Vector2(0, 250))
		root.add_node("hurt_seek", AnimationNodeTimeSeek.new(), Vector2(200, 250))
		root.add_node("hurt_speed", AnimationNodeTimeScale.new(), Vector2(400, 250))
		root.add_node("hurt_blend", _make_hurt_blend(), Vector2(600, 0))
		root.connect_node("hurt_seek", 0, "hurt")
		root.connect_node("hurt_speed", 0, "hurt_seek")
		root.connect_node("hurt_blend", 0, "main")
		root.connect_node("hurt_blend", 1, "hurt_speed")
		root.connect_node("output", 0, "hurt_blend")
	else:
		root.connect_node("output", 0, "main")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = root
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	# カード表示中は SceneTree が止まる。ツリーと同じ扱いにするとアニメーションが 1 度も
	# 適用されないまま止まり、VRM の素の姿勢（T ポーズ）で映る。アニメーションだけは
	# 止めない。ゲーム側の進行（_physics_process）は止まったままなので操作は入らない。
	_tree.process_mode = Node.PROCESS_MODE_ALWAYS
	# ツリーに入れてから anim_player を解決する（get_path_to は両者がツリー内である必要）。
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim_player)
	_tree.active = true

	_state_machine = _tree.get("parameters/main/playback") as AnimationNodeStateMachinePlayback
	_state_machine.start("locomotion")
	if _has_hurt_clip:
		_tree.set("parameters/hurt_blend/blend_amount", 0.0)


## 被弾レイヤー用の Blend2。上半身のトラックだけをフィルタで通し、
## 下半身（LOWER_BODY_BONES）は常に本編側を使う。
func _make_hurt_blend() -> AnimationNodeBlend2:
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	var hurt_anim := _anim_player.get_animation("player/hurt")
	for t in range(hurt_anim.get_track_count()):
		var path := hurt_anim.track_get_path(t)
		var bone := String(path).get_slice(":", 1)
		if not LOWER_BODY_BONES.has(bone):
			blend.set_filter_path(path, true)
	return blend


func _add_transition_once(sm: AnimationNodeStateMachine, from: StringName, to: StringName,
		xfade: float, transition_keys: Dictionary) -> void:
	var key := String(from) + ">" + String(to)
	if transition_keys.has(key):
		return
	transition_keys[key] = true
	_add_transition(sm, from, to, xfade)


func _add_transition(sm: AnimationNodeStateMachine, from: StringName, to: StringName,
		xfade: float) -> void:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = xfade
	tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
	sm.add_transition(from, to, tr)


func _find(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null
