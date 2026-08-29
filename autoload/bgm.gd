extends Node

## 面の音楽の再生（autoload）。曲は作者の自作で、素材は `assets/bgm/*`。
##
## 曲そのものは各 levels/stage_N.tscn の BeltStage が `@export` で持ち、ここが持つのは
## 再生用の枠とフェードだけ（ゲームの進行状態は持たない。可変状態は RunState の役割）。
##
## autoload なので面の切り替えで解放されない。同じ曲を指定した面が続く場合や、
## コンティニューで同じ面を読み直した場合は鳴らし直さず、そのまま繋ぐ。
## 違う曲なら前の曲を絞りながら次を上げる（枠を2本持つのはこの重なりのため）。
##
## 呼び出し側は `Bgm.play(stream)` / `Bgm.stop()`。stream が null なら止める。

## 音楽の音量（dB）。効果音（Sfx.master_volume_db）より低くして台詞と打撃音を通す。
@export var volume_db: float = -14.0
## 曲を上げきるまでの秒数。
@export var fade_in: float = 1.2
## 曲を絞りきるまでの秒数。
@export var fade_out: float = 1.2
## 絞りきった状態の音量（dB）。ここまで下げてから停止する。
@export var silent_db: float = -60.0

var _players: Array[AudioStreamPlayer] = []
## いま鳴らしている枠の番号。
var _current: int = 0
## 絞って止める途中か。ここで「同じ曲が鳴っている」判定を素通りさせると、
## 消えかけの曲をそのまま鳴っている扱いにして無音のままになる。
var _stopping: bool = false
var _fade: Tween = null


func _ready() -> void:
	# テキストカード表示中はツリーが止まる（get_tree().paused）。音楽とフェードは止めない。
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.volume_db = silent_db
		add_child(player)
		_players.append(player)


## 曲を掛ける。同じ曲が鳴っていれば何もしない。
## volume_offset_db は曲ごとの音量差を均すための補正（BeltStage の bgm_volume_db）。
## fade に 0 以上を渡すとフェード時間を上書きする。
func play(stream: AudioStream, volume_offset_db: float = 0.0, fade: float = -1.0) -> void:
	if stream == null:
		stop(fade)
		return
	if _players.is_empty():
		return
	var previous: AudioStreamPlayer = _players[_current]
	if previous.playing and previous.stream == stream and not _stopping:
		return
	_kill_fade()
	_stopping = false
	_current = 1 - _current
	var next: AudioStreamPlayer = _players[_current]
	next.stream = stream
	next.volume_db = silent_db
	next.play()
	var seconds := maxf(fade if fade >= 0.0 else fade_in, 0.0)
	_fade = _new_fade()
	_fade.tween_property(next, "volume_db", volume_db + volume_offset_db, seconds)
	if previous.playing:
		_fade.tween_property(previous, "volume_db", silent_db, seconds)
		_fade.chain().tween_callback(previous.stop)


## 鳴っている曲を絞って止める。
func stop(fade: float = -1.0) -> void:
	_kill_fade()
	var playing: Array[AudioStreamPlayer] = []
	for player in _players:
		if player.playing:
			playing.append(player)
	if playing.is_empty():
		return
	_stopping = true
	var seconds := maxf(fade if fade >= 0.0 else fade_out, 0.0)
	_fade = _new_fade()
	for player in playing:
		_fade.tween_property(player, "volume_db", silent_db, seconds)
	_fade.chain().tween_callback(_stop_all)


## 検証用。いま鳴っている曲（何も鳴っていなければ null）。
func current_stream() -> AudioStream:
	if _players.is_empty():
		return null
	var player: AudioStreamPlayer = _players[_current]
	return player.stream if player.playing else null


## フェード用の Tween。HitStop が Engine.time_scale を落としている最中でも
## 実時間で進めたいので、時間の伸縮を無視する。
func _new_fade() -> Tween:
	return create_tween().set_parallel(true).set_ignore_time_scale(true)


func _stop_all() -> void:
	_stopping = false
	for player in _players:
		player.stop()


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
