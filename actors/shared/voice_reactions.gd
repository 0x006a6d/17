extends Node
class_name VoiceReactions

## 被弾・ダウンの掛け声。`Health` のシグナルを購読して鳴らすだけで、戦闘の処理には
## 触らない（`PlayerSfx` と同じ形。technical-spec §17.6）。
##
## 声の組は .tscn の `@export` で渡す。スクリプト側は素材のパスを持たないので、
## キャラごとに別の声を差せる。
##
## 1体につき `AudioStreamPlayer` を1本しか持たない。同じキャラの声が重なることは
## なく、連続被弾では前の声を切って鳴らし直す（複数の敵が同時に鳴るのは可）。
##
## `Sfx` autoload を経由しないのは、あちらが名前1つに波形1つを対応させる作りで、
## 変化形の抽選も話者ごとの排他も持たないため。

@export_group("Nodes")
## 購読する Health。既定は本体の直下に置かれた Health。
@export var health_path: NodePath = ^"../Health"
@export_group("Clips")
## 被弾（ダウンに至らない）で鳴らす候補。空なら鳴らさない。
@export var hurt_clips: Array[AudioStream] = []
## ダウンで鳴らす候補。空なら鳴らさない。
@export var down_clips: Array[AudioStream] = []
@export_group("Playback")
## 音量（dB）。効果音より前に出すぎないよう既定は控えめ。
@export var volume_db: float = -4.0
## 再生ごとに掛ける音程のばらつき（±この割合）。声色が変わらない程度に留める。
@export var pitch_variation: float = 0.03
## 被弾で声を出す確率。コンボの全段で叫ばせない。
@export_range(0.0, 1.0) var hurt_chance: float = 0.5
## 被弾の声の最短間隔（秒）。連打で声が途切れ続けるのを防ぐ。
@export var hurt_interval: float = 0.7
@export_group("")

var _player: AudioStreamPlayer = null
var _last_hurt_index: int = -1
var _last_down_index: int = -1
## 次に被弾の声を出してよい時刻（`Time.get_ticks_msec()` 基準）。
## 毎フレームの `_process` を全キャラに持たせないための計り方で、
## 停止中も進むが、間隔の下限にしか使わないので影響しない。
var _hurt_ready_msec: int = 0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = &"VoicePlayer"
	_player.bus = &"Master"
	add_child(_player)

	var health := get_node_or_null(health_path) as Health
	if health == null:
		return
	health.staggered.connect(_on_staggered)
	health.downed.connect(_on_downed)


func _on_staggered() -> void:
	if hurt_clips.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now < _hurt_ready_msec:
		return
	if randf() > hurt_chance:
		return
	_hurt_ready_msec = now + int(maxf(hurt_interval, 0.0) * 1000.0)
	_last_hurt_index = _play(hurt_clips, _last_hurt_index)


func _on_downed(_lethal: bool) -> void:
	if down_clips.is_empty():
		return
	# ダウンは抽選も間隔も掛けず必ず鳴らす。倒れる絵に声が付かないと間が抜ける。
	_last_down_index = _play(down_clips, _last_down_index)


## 候補から1つ選んで鳴らし、選んだ番号を返す。直前と同じものは避ける
## （候補が1つのときは避けようがないのでそのまま鳴らす）。
func _play(clips: Array[AudioStream], last_index: int) -> int:
	var index: int = randi() % clips.size()
	if clips.size() > 1 and index == last_index:
		index = (index + 1) % clips.size()
	var stream: AudioStream = clips[index]
	if stream == null or _player == null:
		return last_index
	_player.stream = stream
	_player.volume_db = volume_db
	_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	_player.play()
	return index
