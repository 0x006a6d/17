extends Node
## 回避（dodge）の実測。モーション素材の自然な尺と、ゲーム側の回避ステートの
## 継続秒数・再生速度・移動距離・無敵時間・中断条件を数値で突き合わせる。
## 実行:
##   godot --path . --headless res://tools/test_dodge_timing.tscn
const STAGE := "res://levels/belt_test.tscn"
const MOTION_DIRECTORY := "res://assets/motions/"
const SOURCE_ANIMATION_KEY := "mixamo_com"
const PLAYER_LIBRARY_PREFIX := "player/"
const DODGE_STATE: StringName = &"dodge"
const DODGE_ANIMATION: StringName = &"player/dodge"
const PLAYBACK_PARAMETER := "parameters/main/playback"
const DODGE_SPEED_PARAMETER := "parameters/main/dodge/speed/scale"
## 素材の候補（現行 = backflip）。尺と水平ルートモーションを並べて比較する。
const DODGE_CANDIDATES: Array[String] = [
	"mixamo_dodge_backflip.fbx",
	"mixamo_dodge_backward.fbx",
	"mixamo_dive_roll.fbx",
]
## 骨の回転速度を測る刻み（秒）。この窓ごとの合計角速度で「動きが終わる時刻」を出す。
const MOTION_SAMPLE_STEP: float = 0.05
## 合計角速度がピークのこの割合を下回ったら、動きが終わったとみなす。
const MOTION_TAIL_RATIO: float = 0.05
## 足先の接地判定。立位（先頭キー）の足先高さからこの範囲へ戻ったら接地とみなす（m）。
const FOOT_CONTACT_EPSILON: float = 0.005
## 着地の沈み込みが解けたとみなす腰高さの許容（m）。立位の腰高さからこの範囲。
const HIPS_RECOVERY_EPSILON: float = 0.045
const FOOT_BONES: Array[StringName] = [&"LeftToes", &"RightToes"]
const HIPS_BONE: StringName = &"Hips"
## 無敵の境界を確かめる被弾注入。判定は複数フレーム開ける（hitbox.gd の注記）。
const PROBE_ACTIVE_FRAMES: int = 4
const PROBE_RADIUS: float = 0.5
const PROBE_DAMAGE: float = 10.0
## 注入時刻は素材の実測マーカーから決める。滞空中・接地の瞬間・回避が終わった直後。
const PROBE_AIRBORNE_RATIO: float = 0.5
const PROBE_MARGIN: float = 0.1
## 足が明らかに地面から離れたとみなす高さ（m）。接地中は足先が 0.010〜0.015m を上下する
## ため、踏み切りの判定には接地用より広い幅を使う。
const TAKEOFF_EPSILON: float = 0.03
## 切り出し開始から踏み切りまで（構えの見せ幅）と、接地から切り出し終了までの上限（秒）。
const MAX_WINDUP_LEAD: float = 0.20
const MAX_LANDING_TAIL: float = 0.20
const START_FRAME: int = 8
## 回避が終わってからも余韻を観測するフレーム数。
const OBSERVE_TAIL_FRAMES: int = 40
const CANCEL_PROBE_FRAME_OFFSET: int = 6
const SCALE_TOLERANCE: float = 0.01
const CLIP_CONSUMED_TOLERANCE: float = 0.02
## 再生位置は「ステートが dodge の間」だけ拾うため、PlayerMelee がステートを抜ける
## フレームに追随できず、到達位置は最大2物理フレームぶん手前で観測される。
const PLAY_POSITION_SAMPLE_LAG_FRAMES: float = 2.0
## 上の量子化に float 誤差ぶんの余裕を足す（秒）。
const SAMPLE_EPSILON: float = 0.001
## 「動いた」とみなす1フレームの移動量（m）。減速しきる最終フレームだけはこれを下回る。
const MOVED_STEP_EPSILON: float = 0.001
## 移動が出ていなければならないフレームの割合。
const MOVED_FRAME_RATIO: float = 0.95

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _melee: Node = null
var _tree: AnimationTree = null
var _playback: AnimationNodeStateMachinePlayback = null
var _hurtbox: Area3D = null
var _frame: int = 0
var _phase: int = 0
var _x_start: float = 0.0
## 回避中の1物理フレームごとの本体（CharacterBody3D）の X 変位。
## 「その場でバク転しているだけ」になっていないかを毎フレーム記録して確かめる。
var _step_samples: PackedFloat32Array = PackedFloat32Array()
var _previous_x: float = 0.0
var _dodge_frames: int = 0
var _iframe_frames: int = 0
var _state_entered: bool = false
var _state_left: bool = false
var _max_play_position: float = 0.0
var _distance: float = 0.0
var _speed_scale: float = 0.0
var _clip_length: float = 0.0
var _cancel_probe_left_state: bool = false
var _observe_left: int = 0
var _source_lengths: Dictionary[String, float] = {}
## 元クリップの実測マーカー（秒）。足が接地する時刻と、沈み込みが解けて立ち姿勢へ戻る時刻。
var _takeoff_time: float = 0.0
var _foot_contact_time: float = 0.0
var _stand_recovery_time: float = 0.0
var _trim_start: float = 0.0
var _trim_length: float = 0.0
var _source_clip_length: float = 0.0
var _probe_attacker: Node3D = null
var _probe_hitbox: Hitbox = null
var _iframe_dodge_frame: int = -1
var _probe_index: int = 0
var _probe_times: PackedFloat32Array = PackedFloat32Array()
var _probe_expect_damage: Array[bool] = []
var _probe_active_left: int = 0
var _hp_before_probe: float = 0.0
var _measured_iframe_end: float = -1.0
var _iframe_seen_off: bool = false


func _ready() -> void:
	set_physics_process(false)
	RunState.reset()
	_report_source_clips()
	await _report_foot_phases()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	_melee = _player.get_node(^"PlayerMelee")
	_hurtbox = _player.get_node(^"Hurtbox") as Area3D
	_tree = _melee.get_node_or_null(^"AnimationTree") as AnimationTree
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		(_stage.get_node(dummy_name) as Node3D).global_position = Vector3(60.0, 0.2, 0.0)
	_player.global_position = Vector3(20.0, 0.2, 0.0)
	_player.set("_facing", 1)
	_build_probe_hitbox()
	set_physics_process(true)


# --- 素材側の実測 -------------------------------------------------------

func _report_source_clips() -> void:
	print("=== 回避モーション素材の実測 ===")
	for file_name: String in DODGE_CANDIDATES:
		var animation: Animation = _load_source_animation(MOTION_DIRECTORY + file_name)
		if animation == null:
			print("[skip] %s は読めない" % file_name)
			continue
		_source_lengths[file_name] = animation.length
		var travel: float = RootMotion.horizontal_travel(animation)
		var drift: float = RootMotion.horizontal_max_drift(animation)
		var motion_end: float = _motion_end_time(animation)
		print("[clip] %s length=%.3fs 水平移動=%.3fm 最大水平ドリフト=%.3fm 動きが止まる時刻=%.3fs(%.0f%%)" % [
			file_name, animation.length, travel, drift, motion_end,
			100.0 * motion_end / animation.length if animation.length > 0.0 else 0.0])


func _load_source_animation(scene_path: String) -> Animation:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	var source_player := _find_animation_player(instance) as AnimationPlayer
	var result: Animation = null
	if source_player != null:
		if source_player.has_animation(SOURCE_ANIMATION_KEY):
			result = source_player.get_animation(SOURCE_ANIMATION_KEY).duplicate(true) as Animation
		else:
			for animation_name: String in source_player.get_animation_list():
				if animation_name.ends_with("/" + SOURCE_ANIMATION_KEY):
					result = source_player.get_animation(animation_name).duplicate(true) as Animation
					break
	instance.free()
	return result


## 全回転トラックの合計角速度がピークの MOTION_TAIL_RATIO を最後に上回る時刻。
## クリップ末尾に静止した余韻がどれだけ付いているかを、目視でなく数値で出す。
func _motion_end_time(animation: Animation) -> float:
	var speeds: PackedFloat32Array = _angular_speed_profile(animation)
	if speeds.is_empty():
		return animation.length
	var peak: float = 0.0
	for value: float in speeds:
		peak = maxf(peak, value)
	if peak <= 0.0:
		return animation.length
	var threshold: float = peak * MOTION_TAIL_RATIO
	var last_index: int = 0
	for index: int in range(speeds.size()):
		if speeds[index] >= threshold:
			last_index = index
	return minf(float(last_index + 1) * MOTION_SAMPLE_STEP, animation.length)


func _angular_speed_profile(animation: Animation) -> PackedFloat32Array:
	var sample_count: int = int(animation.length / MOTION_SAMPLE_STEP)
	var profile := PackedFloat32Array()
	if sample_count <= 0:
		return profile
	for sample: int in range(sample_count):
		var time_a: float = float(sample) * MOTION_SAMPLE_STEP
		var time_b: float = time_a + MOTION_SAMPLE_STEP
		var total: float = 0.0
		for track: int in range(animation.get_track_count()):
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var rotation_a: Quaternion = animation.rotation_track_interpolate(track, time_a)
			var rotation_b: Quaternion = animation.rotation_track_interpolate(track, time_b)
			total += absf(rotation_a.angle_to(rotation_b))
		profile.append(total / MOTION_SAMPLE_STEP)
	return profile


## 回避クリップの足の接地時刻を、元 FBX を1フレームずつ送って GeneralSkeleton の
## FK から実測する。Hips の高さは着地後も沈み込みで下がったままなので、接地の根拠には
## 使えない（足先の高さで判定し、腰は「沈み込みが解けて立ち姿勢へ戻る時刻」に使う）。
func _report_foot_phases() -> void:
	var scene_path: String = MOTION_DIRECTORY + DODGE_CANDIDATES[0]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var skeleton: Skeleton3D = _find_skeleton(instance)
	var animation_player: AnimationPlayer = _find_animation_player(instance)
	if skeleton == null or animation_player == null:
		instance.queue_free()
		return
	var animation_name: String = ""
	for candidate: String in animation_player.get_animation_list():
		if candidate == SOURCE_ANIMATION_KEY or candidate.ends_with("/" + SOURCE_ANIMATION_KEY):
			animation_name = candidate
	if animation_name == "":
		instance.queue_free()
		return
	var animation: Animation = animation_player.get_animation(animation_name)
	var fps: float = _source_fps(animation)
	var frame_count: int = int(round(animation.length * fps))
	animation_player.play(animation_name)
	animation_player.pause()

	var foot_heights := PackedFloat32Array()
	var hips_heights := PackedFloat32Array()
	for frame: int in range(frame_count + 1):
		animation_player.seek(float(frame) / fps, true)
		skeleton.force_update_all_bone_transforms()
		var lowest_foot: float = 1.0e9
		for bone_name: StringName in FOOT_BONES:
			var bone: int = skeleton.find_bone(bone_name)
			if bone >= 0:
				lowest_foot = minf(lowest_foot,
					skeleton.get_bone_global_pose(bone).origin.y)
		foot_heights.append(lowest_foot)
		var hips_bone: int = skeleton.find_bone(HIPS_BONE)
		hips_heights.append(skeleton.get_bone_global_pose(hips_bone).origin.y
			if hips_bone >= 0 else 0.0)

	var foot_base: float = foot_heights[0]
	var hips_base: float = hips_heights[0]
	var peak_frame: int = 0
	for frame: int in range(foot_heights.size()):
		if foot_heights[frame] > foot_heights[peak_frame]:
			peak_frame = frame
	var takeoff_frame: int = peak_frame
	for frame: int in range(peak_frame + 1):
		if foot_heights[frame] > foot_base + TAKEOFF_EPSILON:
			takeoff_frame = frame
			break
	var contact_frame: int = frame_count
	for frame: int in range(peak_frame, foot_heights.size()):
		if foot_heights[frame] <= foot_base + FOOT_CONTACT_EPSILON:
			contact_frame = frame
			break
	var recovery_frame: int = frame_count
	for frame: int in range(contact_frame, hips_heights.size()):
		if absf(hips_heights[frame] - hips_base) <= HIPS_RECOVERY_EPSILON:
			recovery_frame = frame
			break
	_takeoff_time = float(takeoff_frame) / fps
	_foot_contact_time = float(contact_frame) / fps
	_stand_recovery_time = float(recovery_frame) / fps
	print("=== 回避クリップの接地・立ち上がり（GeneralSkeleton の FK 実測） ===")
	print("[foot] %s fps=%.1f frames=0..%d 立位の足先高さ=%.4fm 立位の腰高さ=%.4fm" % [
		DODGE_CANDIDATES[0], fps, frame_count, foot_base, hips_base])
	print("[foot] 踏み切り frame=%d t=%.3fs 足先高さ=%.4fm（立位+%.3fm 超）" % [
		takeoff_frame, _takeoff_time, foot_heights[takeoff_frame], TAKEOFF_EPSILON])
	print("[foot] 最高到達 frame=%d t=%.3fs 足先高さ=%.4fm" % [
		peak_frame, float(peak_frame) / fps, foot_heights[peak_frame]])
	print("[foot] 足が接地 frame=%d t=%.3fs 足先高さ=%.4fm（立位+%.4fm 以内）" % [
		contact_frame, _foot_contact_time, foot_heights[contact_frame],
		FOOT_CONTACT_EPSILON])
	print("[foot] 沈み込みが解けて立ち姿勢へ frame=%d t=%.3fs 腰高さ=%.4fm（立位±%.3fm 以内）" % [
		recovery_frame, _stand_recovery_time, hips_heights[recovery_frame],
		HIPS_RECOVERY_EPSILON])
	instance.queue_free()


## 元クリップのフレームレート。回転トラックのキー数と尺から求める。
func _source_fps(animation: Animation) -> float:
	var keys: int = 0
	for track: int in range(animation.get_track_count()):
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			keys = maxi(keys, animation.track_get_key_count(track))
	if keys <= 1 or animation.length <= 0.0:
		return 1.0 / float(Engine.physics_ticks_per_second)
	return float(keys - 1) / animation.length


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


# --- 実機側の実測 -------------------------------------------------------

func _act(action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)


## 本体が毎フレーム実際に後退しているかを、記録した1フレームごとの変位から確かめる。
## RootMotion は水平を潰してあるので、ここに出る移動はすべてコード側の速度によるもの。
func _report_steps(launch_speed: float, delta: float) -> void:
	if _step_samples.is_empty():
		_assert("回避中の1フレームごとの移動を記録できた", false)
		return
	var moved_frames: int = 0
	var forward_frames: int = 0
	var total: float = 0.0
	var largest_step: float = 0.0
	for step: float in _step_samples:
		total += step
		if absf(step) > MOVED_STEP_EPSILON:
			moved_frames += 1
		if step > MOVED_STEP_EPSILON:
			forward_frames += 1
		largest_step = maxf(largest_step, absf(step))
	var expected_first_step: float = launch_speed * delta
	# 記録は各物理フレームの先頭（プレイヤーの _physics_process より前）で取るため、
	# 回避が始まった最初の1フレームだけは移動量 0 が入る。理論初速との突き合わせは
	# 順序に依存しない「最大の1フレーム移動量」で行う。
	print("[measure] 1フレームごとの移動: 記録%dフレーム 動いた%dフレーム 最大=%.4fm(理論 初速*delta=%.4fm) 最終=%.4fm 合計=%.3fm" % [
		_step_samples.size(), moved_frames, largest_step, expected_first_step,
		absf(_step_samples[_step_samples.size() - 1]), absf(total)])
	_assert("回避中はほぼ全フレームで本体が動いている (%d/%d)" % [
		moved_frames, _step_samples.size()],
		float(moved_frames) >= float(_step_samples.size()) * MOVED_FRAME_RATIO)
	_assert("その場に留まっていない（合計 %.3fm が dodge_distance と一致）" % absf(total),
		absf(absf(total) - float(_player.get("dodge_distance"))) <= launch_speed * delta)
	_assert("前方（+X）へ戻るフレームが無い（後方 -X へだけ退く, %d フレーム）" % forward_frames,
		forward_frames == 0)
	_assert("1フレームの最大移動量が逆算した初速と一致する (%.4fm / %.4fm)" % [
		largest_step, expected_first_step],
		absf(largest_step - expected_first_step) <= SAMPLE_EPSILON)


func _read_trim() -> void:
	var action_anim: Node = _player.get_node_or_null(^"PlayerActionAnim")
	if action_anim == null:
		return
	_source_clip_length = float(action_anim.call("source_clip_length", DODGE_STATE))
	var trim: Vector2 = action_anim.call("action_trim", DODGE_STATE)
	_trim_start = trim.x
	_trim_length = trim.y


func _current_state() -> StringName:
	if _playback == null:
		return &""
	return _playback.get_current_node()


func _physics_process(delta: float) -> void:
	_frame += 1
	if _playback == null and _tree != null:
		_playback = _tree.get(PLAYBACK_PARAMETER) as AnimationNodeStateMachinePlayback
	match _phase:
		0:
			_measure_dodge(delta)
		1:
			_probe_attack_cancel()
		2:
			_probe_hurt_cancel()
		3:
			_probe_iframe_window()


func _measure_dodge(delta: float) -> void:
	if _frame < START_FRAME:
		return
	if _frame == START_FRAME:
		_clip_length = float(_melee.call("action_clip_length", DODGE_STATE))
		_read_trim()
		_x_start = _player.global_position.x
		_previous_x = _x_start
		_act("dodge")
		return
	if _frame == START_FRAME + 1:
		_speed_scale = float(_tree.get(DODGE_SPEED_PARAMETER))
	if bool(_player.call("is_dodging")):
		_dodge_frames += 1
		_step_samples.append(_player.global_position.x - _previous_x)
	_previous_x = _player.global_position.x
	if not _hurtbox.monitorable:
		_iframe_frames += 1
	var state: StringName = _current_state()
	if state == DODGE_STATE:
		_state_entered = true
		_max_play_position = maxf(_max_play_position, _playback.get_current_play_position())
	elif _state_entered and not _state_left:
		_state_left = true
		_distance = absf(_player.global_position.x - _x_start)
		_observe_left = OBSERVE_TAIL_FRAMES
	if not _state_left:
		return
	_observe_left -= 1
	if _observe_left > 0:
		return
	_report_measured(delta)
	_phase = 1
	_frame = 0


func _report_measured(delta: float) -> void:
	var duration_setting: float = float(_player.get("dodge_duration"))
	var iframe_setting: float = float(_player.get("dodge_iframes"))
	var dodge_distance: float = float(_player.get("dodge_distance"))
	var launch_speed: float = float(_player.call("_dodge_launch_speed"))
	var measured_duration: float = float(_dodge_frames) * delta
	var measured_iframes: float = float(_iframe_frames) * delta
	# 継続はフレーム量子化で最大 1 物理フレーム伸びる。その間の移動量を許容幅に取る。
	var distance_tolerance: float = launch_speed * delta
	print("=== 回避ステートの実測 ===")
	print("[measure] 切り出し=%.3f〜%.3fs（長さ %.3fs）/ 素材の全長 %.3fs" % [
		_trim_start, _trim_start + _trim_length, _trim_length, _source_clip_length])
	print("[measure] dodge_duration=%.3fs 実測継続=%.3fs (%d 物理フレーム)" % [
		duration_setting, measured_duration, _dodge_frames])
	print("[measure] 登録クリップ長=%.3fs 再生速度=%.3f倍 実効の見え方=%.3fs" % [
		_clip_length, _speed_scale,
		_clip_length / _speed_scale if _speed_scale > 0.0 else 0.0])
	print("[measure] クリップ再生到達位置=%.3fs / %.3fs (%.1f%%)" % [
		_max_play_position, _clip_length,
		100.0 * _max_play_position / _clip_length if _clip_length > 0.0 else 0.0])
	print("[measure] 移動距離 実測=%.3fm / dodge_distance=%.3fm 逆算した初速=%.3fm/s" % [
		_distance, dodge_distance, launch_speed])
	print("[measure] 無敵 dodge_iframes=%.3fs 実測=%.3fs" % [iframe_setting, measured_iframes])

	_assert("回避ステートへ実際に入る", _state_entered)
	_assert("回避ステートを抜ける（無限に居座らない）", _state_left)
	_assert("クリップを最後まで再生し切っている（打ち切られていない） pos=%.3f/%.3f" % [
		_max_play_position, _clip_length],
		_clip_length > 0.0
			and _max_play_position >= _clip_length
				- PLAY_POSITION_SAMPLE_LAG_FRAMES * delta - SAMPLE_EPSILON)
	_assert("再生速度は等速 1.000 倍（早回しでない） scale=%.3f" % _speed_scale,
		absf(_speed_scale - 1.0) <= SCALE_TOLERANCE)
	_assert("ステート継続がクリップ長と一致する（%.3fs / %.3fs）" % [
		measured_duration, _clip_length],
		_clip_length > 0.0 and absf(measured_duration - _clip_length) <= 2.0 * delta)
	_assert("移動距離が dodge_distance と一致する (%.3fm / %.3fm)" % [
		_distance, dodge_distance],
		absf(_distance - dodge_distance) <= distance_tolerance)
	_report_steps(launch_speed, delta)
	_assert("回避の後退が画面端 clamp に張り付いていない (%.3fm)" % _distance,
		_distance >= dodge_distance - distance_tolerance)
	_assert("無敵時間は回避の継続内に収まる (%.3fs <= %.3fs)" % [
		iframe_setting, duration_setting], iframe_setting <= duration_setting)
	_assert("バク転だけを切り出している（素材 %.3fs のうち %.3fs）" % [
		_source_clip_length, _trim_length],
		_trim_length > 0.0 and _trim_length < _source_clip_length)
	_assert("切り出し開始が踏み切り（%.3fs）の直前で、構えが一瞬だけ入る (%.3fs)" % [
		_takeoff_time, _trim_start],
		_trim_start <= _takeoff_time
			and _takeoff_time - _trim_start <= MAX_WINDUP_LEAD)
	_assert("切り出し終了が接地（%.3fs）の直後で、立ち上がりを含まない (%.3fs)" % [
		_foot_contact_time, _trim_start + _trim_length],
		_trim_start + _trim_length >= _foot_contact_time
			and _trim_start + _trim_length - _foot_contact_time <= MAX_LANDING_TAIL)
	_assert("切り出し終了が沈み込み解消（%.3fs）より前（歩き・立ち上がりを含まない）" %
		_stand_recovery_time,
		_trim_start + _trim_length < _stand_recovery_time)
	_assert("dodge_duration が切り出し区間の長さと一致する (%.3fs / %.3fs)" % [
		duration_setting, _trim_length],
		absf(duration_setting - _trim_length) <= CLIP_CONSUMED_TOLERANCE)


# --- 中断条件の切り分け -------------------------------------------------

func _probe_attack_cancel() -> void:
	if _frame == 1:
		_act("dodge")
		return
	if _frame == 1 + CANCEL_PROBE_FRAME_OFFSET:
		_act("attack")
		return
	if _frame == 2 + CANCEL_PROBE_FRAME_OFFSET:
		_cancel_probe_left_state = _current_state() != DODGE_STATE
		_assert("回避中の attack 入力では回避が中断されない（state=%s）" %
			String(_current_state()), not _cancel_probe_left_state)
		return
	if _frame > 2 + CANCEL_PROBE_FRAME_OFFSET and not bool(_player.call("is_dodging")) \
			and _current_state() != DODGE_STATE:
		_phase = 2
		_frame = 0


func _probe_hurt_cancel() -> void:
	# クールダウン明けを待ってからもう一度回避し、無敵が切れた後に被弾させる。
	var cooldown: float = float(_player.get("dodge_cooldown")) \
		+ float(_player.get("dodge_duration"))
	var wait_frames: int = int(ceil(cooldown * float(Engine.physics_ticks_per_second))) + 4
	if _frame == wait_frames:
		_act("dodge")
		return
	if _frame == wait_frames + 2:
		# 被弾リアクションと knockback を回避中に注入する（無敵は Hurtbox 側なので直接呼ぶ）。
		if _player.has_method("receive_knockback"):
			_player.call("receive_knockback", Vector3(1.0, 0.0, 0.0), 5.0)
		return
	if _frame == wait_frames + 4:
		_assert("回避中に被弾しても回避ステートは続く（state=%s）" % String(_current_state()),
			_current_state() == DODGE_STATE and bool(_player.call("is_dodging")))
		_setup_iframe_probes()
		_phase = 3
		_frame = 0


# --- 無敵の窓（開始〜着地）の検証 ---------------------------------------

## Hurtbox の monitorable を切る実装を素通りしないよう、被弾は本物の Hitbox を
## 重ねて Area3D の検出経路から入れる（test_player_hurt_reaction.gd の直接呼び出しは
## 無敵を経由しないため、境界の検証には使えない）。
func _build_probe_hitbox() -> void:
	_probe_attacker = Node3D.new()
	_probe_attacker.name = "ProbeAttacker"
	_stage.add_child(_probe_attacker)
	_probe_hitbox = Hitbox.new()
	_probe_hitbox.name = "ProbeHitbox"
	_probe_hitbox.source_body_path = ^".."
	_probe_attacker.add_child(_probe_hitbox)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	collision.shape = sphere
	_probe_hitbox.add_child(collision)


## 注入時刻は素材の実測マーカーから決める。dodge_iframes から決めると、無敵が
## 短いままでも窓が一緒に縮んで通ってしまい、回帰を検出できない。
func _setup_iframe_probes() -> void:
	var duration: float = float(_player.get("dodge_duration"))
	# 切り出したので、回避中はすべて空中。無防備になるのは回避が終わった後だけ。
	_probe_times = PackedFloat32Array([
		duration * PROBE_AIRBORNE_RATIO,
		maxf(_foot_contact_time - _trim_start, 0.0),
		duration + PROBE_MARGIN,
	])
	_probe_expect_damage = [false, false, true]


func _probe_iframe_window() -> void:
	if _iframe_dodge_frame < 0:
		if float(_player.get("_dodge_cooldown_left")) > 0.0 \
				or float(_player.get("_hurt_timer")) > 0.0:
			return
		_act("dodge")
		_iframe_dodge_frame = _frame
		return
	var delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	var elapsed: float = float(_frame - _iframe_dodge_frame) * delta
	# monitorable=false は set_deferred で次のフレームに反映されるため、一度 false を
	# 観測してから true への復帰を無敵終了とする。
	if not _hurtbox.monitorable:
		_iframe_seen_off = true
	elif _iframe_seen_off and _measured_iframe_end < 0.0:
		_measured_iframe_end = elapsed
	if _probe_active_left > 0:
		_probe_attacker.global_position = _player.global_position
		_probe_active_left -= 1
		if _probe_active_left == 0:
			_finish_probe(elapsed)
		return
	if _probe_index >= _probe_times.size():
		_report_iframe_window()
		return
	if elapsed < _probe_times[_probe_index]:
		return
	_hp_before_probe = float(_player.call("current_hp"))
	_probe_attacker.global_position = _player.global_position
	_probe_hitbox.configure(PROBE_DAMAGE, 0.0, false)
	_probe_hitbox.activate()
	_probe_active_left = PROBE_ACTIVE_FRAMES


func _finish_probe(elapsed: float) -> void:
	_probe_hitbox.deactivate()
	var hp_after: float = float(_player.call("current_hp"))
	var took_damage: bool = hp_after < _hp_before_probe
	var expected: bool = _probe_expect_damage[_probe_index]
	var label: String = "被弾する" if expected else "被弾しない"
	_assert("回避 %.3f 秒時点で%s（HP %.0f→%.0f, 注入 %.3f 秒）" % [
		_probe_times[_probe_index], label, _hp_before_probe, hp_after, elapsed],
		took_damage == expected)
	_probe_index += 1


func _report_iframe_window() -> void:
	var iframes: float = float(_player.get("dodge_iframes"))
	var delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	print("=== 無敵の窓 ===")
	print("[measure] dodge_iframes=%.3fs 実測の無敵終了=%.3fs 区間内の接地=%.3fs 区間長=%.3fs" % [
		iframes, _measured_iframe_end,
		maxf(_foot_contact_time - _trim_start, 0.0), _trim_length])
	var contact_in_state: float = maxf(_foot_contact_time - _trim_start, 0.0)
	_assert("無敵が足の接地（区間内 %.3f 秒）以降まで続く (dodge_iframes=%.3f)" % [
		contact_in_state, iframes], iframes >= contact_in_state)
	_assert("無敵が切り出し区間の全体（空中）を覆う (%.3fs >= %.3fs)" % [
		iframes, _trim_length], iframes >= _trim_length - CLIP_CONSUMED_TOLERANCE)
	_assert("実測の無敵終了が dodge_iframes と一致する (%.3fs / %.3fs)" % [
		_measured_iframe_end, iframes],
		_measured_iframe_end >= 0.0
			and absf(_measured_iframe_end - iframes) <= 2.0 * delta)
	_finish()


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
