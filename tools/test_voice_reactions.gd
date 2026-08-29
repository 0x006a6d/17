extends Node

## 被弾・ダウンの掛け声（`actors/shared/voice_reactions.gd`）の検証。
##   godot --path . --headless res://tools/test_voice_reactions.tscn
##
## 見るのは次の4点。音そのものは耳で確かめるしかないので、ここでは
## 「実戦と同じ経路で鳴る指示が出ているか」だけを機械的に確かめる。
##   (1) 3つのシーンに声の組が入っていて、どの候補も null でない
##   (2) ループが無効（有効だと呻き声が鳴り止まなくなる）
##   (3) Health.staggered / Health.downed で実際に再生が始まる
##   (4) 1体につき AudioStreamPlayer は1本だけで、
##       hurt_interval の間は続けて鳴らない（連続被弾で声が途切れ続けない）
##   (5) 出撃する敵シーンが1つ残らず声を持つ（役割シーンは enemy.tscn を継承する
##       約束なので、継承しないものが足されたらここで落ちる）

const SCENES: Dictionary = {
	"プレイヤー": "res://actors/player/player.tscn",
	"敵": "res://actors/enemy/enemy.tscn",
	"最終ボス": "res://actors/boss/nike.tscn",
}
## 振る舞いを確かめる対象。VRM を必要としない敵を使う。
const BEHAVIOUR_SCENE: String = "res://actors/enemy/enemy.tscn"
## よろけ止まりにするダメージ（max_hp 30000 に対して十分小さい）。
const STAGGER_DAMAGE: float = 1000.0
## 確実にダウンさせるダメージ。
const LETHAL_DAMAGE: float = 100000.0
## 間隔の検証で使う待ち時間（秒）。この間は2度目を鳴らさない。
const LONG_INTERVAL: float = 5.0
## 出撃する敵シーンを置いてあるディレクトリ。
const ENEMY_DIRS: Array[String] = [
	"res://actors/enemy/roles",
	"res://actors/enemy/bosses",
]

var _failures: int = 0


func _ready() -> void:
	print("=== 被弾・ダウンの掛け声 検証 ===")
	for label: String in SCENES:
		await _check_wiring(label, String(SCENES[label]))
	await _check_playback()
	_check_all_enemy_scenes()
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


## (1)(2) シーンに声の組が入っているか。
## 出したインスタンスは終了まで置いたままにする（他の検証ツールと同じ）。
## ツリーへ入れずに free() すると VRM/FBX のサブリソースが残って leak として
## 報告され、ツリーへ入れてから free() するとダミーレンダラがマテリアル欠落を
## エラーに出す。どちらも検証内容とは関係しないので、解放は終了時に任せる。
func _check_wiring(label: String, scene_path: String) -> void:
	var body := (load(scene_path) as PackedScene).instantiate() as Node3D
	add_child(body)
	await get_tree().physics_frame
	var voice := body.get_node_or_null("Voice") as VoiceReactions
	if voice == null:
		_check(false, "%s: Voice ノードがある" % label)
		return
	_check(true, "%s: Voice ノードがある" % label)
	_check(voice.hurt_clips.size() > 0, "%s: 被弾の声がある（%d本）"
		% [label, voice.hurt_clips.size()])
	_check(voice.down_clips.size() > 0, "%s: ダウンの声がある（%d本）"
		% [label, voice.down_clips.size()])
	var clips: Array[AudioStream] = []
	clips.append_array(voice.hurt_clips)
	clips.append_array(voice.down_clips)
	var nulls: int = 0
	var looped: int = 0
	for clip: AudioStream in clips:
		if clip == null:
			nulls += 1
			continue
		var wav := clip as AudioStreamWAV
		if wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			looped += 1
	_check(nulls == 0, "%s: 読み込めない候補が無い" % label)
	_check(looped == 0, "%s: ループが無効" % label)


## (3)(4) 実際に Health のシグナルで鳴るか。
func _check_playback() -> void:
	var body := (load(BEHAVIOUR_SCENE) as PackedScene).instantiate() as Node3D
	add_child(body)
	await get_tree().physics_frame
	var voice := body.get_node_or_null("Voice") as VoiceReactions
	var health := body.get_node_or_null("Health") as Health
	if voice == null or health == null:
		_check(false, "検証用の敵に Voice と Health がある")
		return

	var players: Array[Node] = voice.find_children("*", "AudioStreamPlayer", true, false)
	_check(players.size() == 1, "1体につき再生枠は1本（同じ声が重ならない）")
	if players.size() != 1:
		return
	var stream_player := players[0] as AudioStreamPlayer

	# 抽選と間隔を外して、被弾で必ず鳴る状態にする。
	voice.hurt_chance = 1.0
	voice.hurt_interval = 0.0
	health.take_hit(STAGGER_DAMAGE)
	_check(stream_player.playing, "被弾（staggered）で鳴る")
	_check(stream_player.stream != null, "被弾で候補が選ばれている")

	# 間隔を空けたら、その間は2度目を鳴らさない。
	voice.hurt_interval = LONG_INTERVAL
	health.take_hit(STAGGER_DAMAGE)   # 間隔の起点を作る
	stream_player.stop()
	health.take_hit(STAGGER_DAMAGE)
	_check(not stream_player.playing, "hurt_interval の間は続けて鳴らさない")

	stream_player.stop()
	health.take_hit(LETHAL_DAMAGE)
	_check(health.is_downed(), "ダウンしている（前提）")
	_check(stream_player.playing, "ダウン（downed）で鳴る")


## (5) 役割シーン・ボスシーンが1つ残らず声を持つか。
## ここはシーンを開かず PackedScene の中身だけを見る（モデルを読み込まない）。
func _check_all_enemy_scenes() -> void:
	var missing: Array[String] = []
	var checked: int = 0
	for dir_path: String in ENEMY_DIRS:
		for file_name: String in _scene_files(dir_path):
			var path: String = "%s/%s" % [dir_path, file_name]
			checked += 1
			if not _scene_has_voice(load(path) as PackedScene):
				missing.append(file_name)
	_check(checked > 0, "敵シーンを走査できた（%d件）" % checked)
	_check(missing.is_empty(), "全ての敵シーンが声を持つ%s"
		% ("" if missing.is_empty() else "（欠け: %s）" % ", ".join(missing)))


func _scene_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for file_name: String in dir.get_files():
		# 書き出し後は .tscn が .scn になる。両方拾う。
		if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			files.append(file_name)
	files.sort()
	return files


## 継承元をたどって Voice ノードの有無を見る。
func _scene_has_voice(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var state := scene.get_state()
	for i: int in state.get_node_count():
		if state.get_node_name(i) == &"Voice":
			return true
	# 継承したノードは子シーン側に載っているので、継承元をたどる。
	for i: int in state.get_node_count():
		var nested := state.get_node_instance(i)
		if nested != null and _scene_has_voice(nested):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
