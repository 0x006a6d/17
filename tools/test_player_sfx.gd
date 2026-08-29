extends Node

## 素手の命中音の割り当てと重複抑止の検証。
##   godot --path . --headless res://tools/test_player_sfx.tscn
##
##   (1) ジャブ・ストレートは hit_punch、膝・ミドルは hit_kick、
##       フック・ハイは hit_finish を鳴らす
##   (2) 締めの技（フック・ハイ）は finish_volume_db で他より大きく鳴る
##   (3) player.tscn と同じノード名で組めば MeleeHitbox と PlayerMelee に繋がる
##   (4) 同じ物理フレームに複数の相手へ当たっても命中音は 1 回だけ
##   (5) 使う音が Sfx に登録されていて、素材が 3 本とも別物である
##
## 実際の再生は Sfx autoload なので、このテストでは Sfx のスクリプトを記録用に差し替える。
## 差し替えはこのテストプロセス内だけの話で、終了と同時に消える。

const ComboTree := preload("res://actors/player/combo_tree.gd")
const PLAYER_SFX := preload("res://actors/player/player_sfx.gd")
const HITBOX := preload("res://actors/shared/hitbox.gd")


## Sfx autoload の代わりに呼び出しを記録するだけのスクリプト。
class StubSfx extends Node:
	var calls: Array = []

	func play(sound: StringName, volume_db: float = 0.0) -> void:
		calls.append([sound, volume_db])


## PlayerMelee の代わりに stage_started だけを出すノード。
class StubMelee extends Node:
	signal stage_started(technique: StringName, stage: int)


var _pass: int = 0
var _fail: int = 0
var _sfx: PlayerSfx = null
var _hitbox: Hitbox = null
var _melee: StubMelee = null
var _frames: int = 0


func _ready() -> void:
	print("=== 素手の命中音 検証開始 ===")
	var registered: Dictionary = Sfx.get("STREAMS") as Dictionary
	Sfx.set_script(StubSfx)
	Sfx.set("calls", [])

	# player.tscn と同じ形（Player/Model/MeleeHitbox, Player/PlayerMelee, Player/PlayerSfx）。
	var player := Node.new()
	player.name = "Player"
	add_child(player)
	var model := Node3D.new()
	model.name = "Model"
	player.add_child(model)
	var area := Area3D.new()
	area.set_script(HITBOX)
	_hitbox = area as Hitbox
	_hitbox.name = "MeleeHitbox"
	model.add_child(_hitbox)
	_melee = StubMelee.new()
	_melee.name = "PlayerMelee"
	player.add_child(_melee)
	_sfx = PLAYER_SFX.new() as PlayerSfx
	_sfx.name = "PlayerSfx"
	player.add_child(_sfx)

	_check_registration(registered)
	_check_mapping()
	_check_wiring()
	set_physics_process(true)


## (5) 鳴らそうとしている名前が Sfx に登録済みで、素材が互いに別ファイルか。
func _check_registration(registered: Dictionary) -> void:
	for sound in [_sfx.punch_sound, _sfx.kick_sound, _sfx.finish_sound]:
		_assert("(5) %s が Sfx に登録されている" % sound, registered.has(sound))
	var streams: Array = []
	for sound in [_sfx.punch_sound, _sfx.kick_sound, _sfx.finish_sound]:
		var stream: AudioStream = registered.get(sound) as AudioStream
		if stream != null and not streams.has(stream.resource_path):
			streams.append(stream.resource_path)
	_assert("(5) 3種が別の素材を指している (実測 %d 本)" % streams.size(),
		streams.size() == 3)


## (1)(2) 技ごとの音と音量。
func _check_mapping() -> void:
	var expected: Dictionary = {
		ComboTree.TECHNIQUE_JAB: _sfx.punch_sound,
		ComboTree.TECHNIQUE_STRAIGHT: _sfx.punch_sound,
		ComboTree.TECHNIQUE_KNEE: _sfx.kick_sound,
		ComboTree.TECHNIQUE_MIDDLE: _sfx.kick_sound,
		ComboTree.TECHNIQUE_HOOK: _sfx.finish_sound,
		ComboTree.TECHNIQUE_HIGH: _sfx.finish_sound,
	}
	for technique in ComboTree.TECHNIQUES:
		var want: StringName = expected[technique]
		var got: StringName = _sfx.call("_sound_for", technique)
		_assert("(1) %s → %s (実測 %s)" % [technique, want, got], got == want)
	_assert("(1) 3種の音が互いに別名である",
		_sfx.punch_sound != _sfx.kick_sound
			and _sfx.kick_sound != _sfx.finish_sound
			and _sfx.punch_sound != _sfx.finish_sound)
	var finish_db: float = _sfx.call("_volume_for", ComboTree.TECHNIQUE_HOOK)
	var jab_db: float = _sfx.call("_volume_for", ComboTree.TECHNIQUE_JAB)
	_assert("(2) 締めの技のほうが大きい (%.1f dB > %.1f dB)" % [finish_db, jab_db],
		finish_db > jab_db)


## (3) 既定の NodePath で MeleeHitbox と PlayerMelee に繋がっているか。
func _check_wiring() -> void:
	_assert("(3) MeleeHitbox の hit_landed に繋がっている",
		_hitbox.hit_landed.get_connections().size() == 1)
	_assert("(3) PlayerMelee の stage_started に繋がっている",
		_melee.stage_started.get_connections().size() == 1)
	_calls().clear()
	_melee.stage_started.emit(ComboTree.TECHNIQUE_KNEE, 1)
	_hitbox.hit_landed.emit(null)
	var calls: Array = _calls()
	_assert("(3) 膝の命中で kick_sound が 1 回鳴る (実測 %s)" % [calls],
		calls.size() == 1 and calls[0][0] == _sfx.kick_sound)


## (4) 同フレームの多段ヒットは 1 回、次フレームなら鳴り直す。
func _physics_process(_delta: float) -> void:
	_frames += 1
	match _frames:
		1:
			_calls().clear()
			_melee.stage_started.emit(ComboTree.TECHNIQUE_HOOK, 3)
			_hitbox.hit_landed.emit(null)
			_hitbox.hit_landed.emit(null)
			_hitbox.hit_landed.emit(null)
			var calls: Array = _calls()
			_assert("(4) 3体同時ヒットでも命中音は 1 回 (実測 %d 回)" % calls.size(),
				calls.size() == 1)
			_assert("(4) 鳴ったのは finish_sound", calls.size() == 1
				and calls[0][0] == _sfx.finish_sound)
		2:
			_hitbox.hit_landed.emit(null)
			_assert("(4) 次のフレームでは鳴り直す (実測 %d 回)" % _calls().size(),
				_calls().size() == 2)
			_finish()


func _calls() -> Array:
	return Sfx.get("calls") as Array


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
