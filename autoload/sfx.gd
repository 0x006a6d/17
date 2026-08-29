extends Node

## 効果音の再生（autoload）。素材は `assets/sfx/*.wav` で、いずれも CC0 の実録音を
## 切り出したもの。取得元は `assets/sfx/SOURCES.md`。
##
## 同じ音が続けて鳴っても切れないよう、AudioStreamPlayer を数本持ち回す。ここが持つのは
## その再生用の枠だけで、ゲームの進行状態は持たない（可変状態は RunState の役割）。
##
## 呼び出し側は `Sfx.play(&"gun_shot")` のように名前で指定する。

const STREAMS: Dictionary = {
	&"gun_shot": preload("res://assets/sfx/gun_shot.wav"),
	&"rifle_shot": preload("res://assets/sfx/rifle_shot.wav"),
	&"gun_dry": preload("res://assets/sfx/gun_dry.wav"),
	&"gun_reload": preload("res://assets/sfx/gun_reload.wav"),
	&"hit_punch": preload("res://assets/sfx/hit_punch.wav"),
	&"hit_kick": preload("res://assets/sfx/hit_kick.wav"),
	&"hit_finish": preload("res://assets/sfx/hit_finish.wav"),
	&"katana_slash": preload("res://assets/sfx/katana_slash.wav"),
	&"enemy_down": preload("res://assets/sfx/enemy_down.wav"),
}

## 同時に鳴らせる本数。枠は順番に使い回す（再生中でも次の順番の枠を上書きする）。
@export var voices: int = 10
## 全体の音量（dB）。
@export var master_volume_db: float = -6.0
## 再生ごとに掛ける音程のばらつき（±この割合）。同じ音の連打を機械的に聞かせない。
@export var pitch_variation: float = 0.06

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(maxi(voices, 1)):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


## 名前で鳴らす。未登録の名前は無視する（音が無くてもゲームは進む）。
func play(sound: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = STREAMS.get(sound) as AudioStream
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _pick()
	player.stream = stream
	player.volume_db = master_volume_db + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## 空いている枠を探す。全部埋まっていたら順番に奪う。
func _pick() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var picked: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	return picked
