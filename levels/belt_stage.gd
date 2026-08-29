extends Node3D
class_name BeltStage

## 面の共通スクリプト（technical-spec §12）。各 stage_N.tscn のルートに付ける。
## プレイヤーへベルト幅、カメラへ可動範囲を渡し、LockPoint / BossTrigger を束ねて
## StageDirector へ進行を通知する。敵の実体化（出現位置）もここが担う。

@export_group("Belt")
## ベルトの X 範囲（m）。カメラ中心はこの内側（半画面ぶん）だけ動く。
@export var x_min: float = 0.0
@export var x_max: float = 60.0
## ベルトの奥行き範囲（m）。
@export var belt_z_min: float = -1.5
@export var belt_z_max: float = 1.5
## 敵を出す位置の、画面端からの外側距離（m）。
@export var spawn_margin: float = 1.5

@export_group("Ground")
## 地面テクスチャ（タイル）。存在すれば床のマテリアルに貼る。無ければ今の単色のまま。
@export_file("*.png") var ground_texture_path: String = ""
## テクスチャ1枚が覆う床のワールド寸法（m）。床の長さ／この値ぶん X 方向に繰り返す。
@export var ground_tile_size: float = 8.0
## 床メッシュ（MeshInstance3D）。
@export var floor_mesh_path: NodePath = ^"Floor/MeshInstance3D"

@export_group("Stage")
## この面の番号（GameTypes.Stage）。
@export var stage: int = GameTypes.Stage.STAGE_1
## 次の面のシーンパス。空ならここで終わる。
@export_file("*.tscn") var next_stage: String = ""
## 面の題名。カードを閉じたあと、画面上中央に出す。空なら出さない。
@export var stage_title: String = ""
## 面の冒頭に出すカードの文言。空ならカード無しで即プレイ。
@export var opening_lines: Array[String] = []
## 冒頭カードの立ち絵（パス。ファイルが無ければ立ち絵無しで出す。公式三面図は
## リポジトリに含めないため、存在チェックしてから読む）と体裁。
@export_file("*.png") var opening_portrait_path: String = ""
@export var opening_monospace_green: bool = false
## ボス撃破後に出すカードの文言（4面の開示など）。空なら出さない。
@export var reveal_lines: Array[String] = []
## 開示カードを出すまでの秒数（ボスの倒れ込みを見せる）。
@export var reveal_delay: float = 1.5
## 開示カードの後に白フラッシュを入れる。
@export var reveal_flash: bool = false
@export var reveal_flash_duration: float = 0.12
## 開示カードの直前に人質（グループ hostage）を立ち上がらせる。
@export var reveal_hostage_stands: bool = false
## ボス撃破から次の面へ移るまでの秒数（開示カードが無い場合）。通常ボスの
## despawn_delay=4.0 より先に面を切り替えず、倒れ込みと消滅前点滅を最後まで見せる。
@export var next_stage_delay: float = 4.0
## ボス戦に出す雑魚の同時上限。供回りも増援もこの数までしか画面に出さず、
## 超えた分は誰か倒れてから順に出す。
@export var boss_mobs_max_alive: int = 2
## ボスの増援要請（adds_requested）で出す敵。
@export var adds_scene: PackedScene = preload("res://actors/enemy/enemy.tscn")
## 増援を種類ごとに出し分ける場合の一覧。空でなければ adds_scene より優先し、
## 先頭から順に使い回す（5面は雑魚とニケ素体を1体ずつ出す）。
@export var adds_scenes: Array[PackedScene] = []
## ボス戦の開始と同時に出す供回り。ボスと一緒に戦う（4面のゾンビ）。
## 画面外から左右交互に歩き込ませ、倒しても面の進行（ボス撃破）には影響しない。
@export var boss_escorts: Array[PackedScene] = []
## コンティニューの待ち秒数。
@export var continue_timeout: float = 10.0
## コンティニュー・ゲームオーバー時にシーンを切り替える（テストでは false）。
@export var change_scene_on_continue: bool = true
## 最後に得点と X 投稿ボタンの結果画面を出す。
@export var show_result_panel: bool = true

@export_group("Audio")
## この面で鳴らす曲（`assets/bgm/`。取得元は `assets/bgm/SOURCES.md`）。
## 空なら、鳴っていた曲を絞って止める。前の面と同じ曲を指定した場合と、
## コンティニューで面を読み直した場合は鳴らし直さず繋ぐ。
@export var bgm: AudioStream = null
## 曲ごとの音量差を均す補正（dB）。Bgm.volume_db に足す。
## 5曲の integrated loudness には -8.7〜-11.3 LUFS の幅があるので、
## いちばん小さい曲（1面）に合わせて他を下げている。
@export var bgm_volume_db: float = 0.0

@export_group("Nodes")
@export var player_path: NodePath = ^"Player"
@export var camera_path: NodePath = ^"BeltCamera"
## 実体化した敵を入れる親。
@export var enemies_path: NodePath = ^"Enemies"
@export var lock_points: Array[NodePath] = []
@export var boss_trigger_path: NodePath
@export_group("")

var _player: Node3D = null
var _camera: BeltCamera = null
var _enemies_root: Node = null
var _locks: Array[LockPoint] = []
var _boss_trigger: BossTrigger = null
var _boss: Node3D = null
## ボス戦に出ている雑魚と、上限に掛かって待たせている分。
var _boss_mobs: Array[Node3D] = []
var _boss_mob_queue: Array[PackedScene] = []
## 出した数。左右交互に出すために使う。
var _boss_mob_count: int = 0
## 増援シーンの順番。供回りの待ち行列や同時出現数とは独立して進める。
var _adds_scene_index: int = 0
var _card: TextCard = null
var _result_panel: ResultPanel = null
var _continue_result: String = ""

const TEXT_CARD_SCENE := "res://ui/text_card.tscn"
const RESULT_PANEL_SCENE := "res://ui/result_panel.tscn"
## 最終面のあとやゲームオーバーで戻る先。
const TITLE_SCENE := "res://ui/title_screen.tscn"


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_camera = get_node_or_null(camera_path) as BeltCamera
	_enemies_root = get_node_or_null(enemies_path)
	if _enemies_root == null:
		_enemies_root = self
	if _player != null and _player.has_method("set_belt_bounds"):
		_player.call("set_belt_bounds", belt_z_min, belt_z_max)
	if _player != null and _player.has_signal("player_out_of_lives"):
		_player.connect("player_out_of_lives", _on_player_out_of_lives)
	if _camera != null:
		if _player != null:
			_camera.set_target(_player)
		var half := _camera.half_width_at_belt()
		_camera.set_x_limits(x_min + half, x_max - half)
		_camera.position.x = clampf(_camera.position.x, x_min + half, x_max - half)
	for path in lock_points:
		var lp := get_node_or_null(path) as LockPoint
		if lp == null:
			continue
		_locks.append(lp)
		lp.reached.connect(_on_lock_reached)
		lp.cleared.connect(_on_lock_cleared)
	if not boss_trigger_path.is_empty():
		_boss_trigger = get_node_or_null(boss_trigger_path) as BossTrigger
		if _boss_trigger != null:
			_boss_trigger.reached.connect(_on_boss_trigger_reached)
			# 面に置いてあるボス（4面の盾持ち）は、そのままだと開始直後から歩いてきて
			# ロック地点の戦いに割り込む。ボス戦が始まるまで動かさない。
			var placed := _boss_trigger.placed_boss()
			if placed != null:
				placed.set_physics_process(false)
	_apply_ground_texture()
	Bgm.play(bgm, bgm_volume_db)
	StageDirector.begin_stage(stage, not opening_lines.is_empty())
	if opening_lines.is_empty():
		StageDirector.notify_card_closed()
		StageDirector.notify_stage_title(stage_title)
	else:
		var portrait: Texture2D = null
		if not opening_portrait_path.is_empty() and ResourceLoader.exists(opening_portrait_path):
			portrait = load(opening_portrait_path) as Texture2D
		_show_card(opening_lines, portrait, opening_monospace_green, _on_opening_card_closed)


func _on_opening_card_closed() -> void:
	StageDirector.notify_card_closed()
	StageDirector.notify_stage_title(stage_title)


## カードを 1 枚出す。閉じたら on_closed を呼ぶ。
func _show_card(card_lines: Array[String], card_portrait: Texture2D,
		monospace_green: bool, on_closed: Callable) -> void:
	if _card == null:
		var packed := load(TEXT_CARD_SCENE) as PackedScene
		if packed == null:
			push_warning("belt_stage: text_card.tscn が無い")
			on_closed.call()
			return
		_card = packed.instantiate() as TextCard
		add_child(_card)
	_card.lines = card_lines
	_card.portrait = card_portrait
	_card.monospace_green = monospace_green
	for c in _card.closed.get_connections():
		_card.closed.disconnect(c["callable"])
	_card.closed.connect(on_closed, CONNECT_ONE_SHOT)
	# 同じフレーム内の信号処理から呼ばれても安全なよう 1 フレーム遅らせる。
	_card.show_card.call_deferred()


func text_card() -> TextCard:
	return _card


# --- 画面ロック ----------------------------------------------------------

func _on_lock_reached(lp: LockPoint) -> void:
	var index := _locks.find(lp)
	if _camera != null:
		_camera.lock_at(_camera.position.x)
	StageDirector.notify_lock_started(index)
	lp.start(_spawn_enemy)


func _on_lock_cleared(lp: LockPoint) -> void:
	var index := _locks.find(lp)
	if _camera != null:
		_camera.unlock()
	StageDirector.notify_lock_cleared(index)


# --- ボス ---------------------------------------------------------------

func _on_boss_trigger_reached(trigger: BossTrigger) -> void:
	if _camera != null:
		_camera.lock_at(trigger.lock_x if trigger.use_lock_x else _camera.position.x)
	# body_entered の信号処理中に Area3D を持つ敵を add_child すると、その _ready の
	# monitorable 設定が弾かれる（"Function blocked during in/out signal"）。1 フレーム遅らせる。
	_spawn_boss.call_deferred(trigger)


func _spawn_boss(trigger: BossTrigger) -> void:
	_boss = trigger.placed_boss()
	if _boss == null:
		_boss = _spawn_enemy(trigger.boss_scene, trigger.side)
	if _boss == null:
		push_warning("belt_stage: boss_scene / boss_path が無い")
		return
	if _boss.has_signal("defeated"):
		_boss.connect("defeated", _on_boss_defeated)
	if _boss.has_signal("adds_requested"):
		_boss.connect("adds_requested", _on_adds_requested)
	_boss.set_physics_process(true)
	StageDirector.notify_boss_started(_boss)
	_queue_boss_mobs(boss_escorts)


## ボスの増援。左右交互に出す。被弾のシグナル処理中から呼ばれるため、Area3D を持つ敵の
## 生成は次の物理ステップへ遅延する（in/out signal 中の set_monitorable ブロック回避）。
func _on_adds_requested(count: int) -> void:
	_spawn_adds.call_deferred(count)


func _spawn_adds(count: int) -> void:
	var scenes: Array[PackedScene] = []
	for _i: int in range(count):
		scenes.append(_adds_scene_at(_adds_scene_index))
		_adds_scene_index += 1
	_queue_boss_mobs(scenes)


## ボス戦の雑魚を待ち行列へ入れ、空きぶんだけ出す。
func _queue_boss_mobs(scenes: Array[PackedScene]) -> void:
	for scene: PackedScene in scenes:
		if scene != null:
			_boss_mob_queue.append(scene)
	_pump_boss_mobs()


## 上限に空きがある間だけ待ち行列から出す。
func _pump_boss_mobs() -> void:
	# 面切り替えでこのStageとEnemiesが解放待ちの間にも、雑魚のtree_exitedが
	# 遅れて届く。新しい敵を解放待ちの親へ追加しない。
	if not is_inside_tree() or is_queued_for_deletion() \
			or _enemies_root == null or not is_instance_valid(_enemies_root) \
			or not _enemies_root.is_inside_tree() \
			or _enemies_root.is_queued_for_deletion():
		return
	_prune_boss_mobs()
	var limit: int = maxi(boss_mobs_max_alive, 1)
	while not _boss_mob_queue.is_empty() and _boss_mobs.size() < limit:
		var scene: PackedScene = _boss_mob_queue.pop_front()
		var side: int = 1 if _boss_mob_count % 2 == 0 else -1
		_boss_mob_count += 1
		var mob := _spawn_enemy(scene, side)
		if mob == null:
			continue
		_boss_mobs.append(mob)
		if mob.has_signal("defeated"):
			mob.connect("defeated", _on_boss_mob_defeated)
		mob.tree_exited.connect(_on_boss_mob_gone.bind(mob))


func _on_boss_mob_defeated(mob: Node3D) -> void:
	_boss_mobs.erase(mob)
	_pump_boss_mobs.call_deferred()


func _on_boss_mob_gone(mob: Node3D) -> void:
	_boss_mobs.erase(mob)
	_pump_boss_mobs.call_deferred()


func _prune_boss_mobs() -> void:
	for i: int in range(_boss_mobs.size() - 1, -1, -1):
		var mob := _boss_mobs[i]
		if mob == null or not is_instance_valid(mob) or not mob.is_inside_tree():
			_boss_mobs.remove_at(i)


## i 体目の増援に使うシーン。adds_scenes を指定した面はそれを順に使う。
func _adds_scene_at(index: int) -> PackedScene:
	if adds_scenes.is_empty():
		return adds_scene
	return adds_scenes[index % adds_scenes.size()]


func _on_boss_defeated(_boss_node: Node3D) -> void:
	StageDirector.notify_boss_defeated(stage)
	if not reveal_lines.is_empty():
		get_tree().create_timer(reveal_delay).timeout.connect(_begin_reveal)
		return
	# ボスの倒れ込みを見せてから次の面へ。次の面が無ければ _go_next_stage が結果画面へ進める。
	get_tree().create_timer(next_stage_delay).timeout.connect(_go_next_stage)


## 開示: 人質が立ち上がり、カードを出し、閉じたら白フラッシュ → 次の面。
func _begin_reveal() -> void:
	if reveal_hostage_stands:
		for node in get_tree().get_nodes_in_group(&"hostage"):
			if node.has_method("stand_up"):
				node.call("stand_up")
	_show_card(reveal_lines, null, false, _on_reveal_card_closed)


func _on_reveal_card_closed() -> void:
	if reveal_flash:
		_flash_white(reveal_flash_duration)
		get_tree().create_timer(reveal_flash_duration + 0.2).timeout.connect(_go_next_stage)
		return
	_go_next_stage()


# --- 残機・コンティニュー ------------------------------------------------------

func _on_player_out_of_lives() -> void:
	var card_lines: Array[String] = [
		"CONTINUE?   残り %d" % RunState.continues,
		">  Enter / Space で続ける",
	]
	if _card == null:
		var packed := load(TEXT_CARD_SCENE) as PackedScene
		_card = packed.instantiate() as TextCard
		add_child(_card)
	_card.auto_close_after = continue_timeout
	_card.chars_per_second = 200.0
	_show_card(card_lines, null, false, _on_continue_card_closed)


func _on_continue_card_closed() -> void:
	_card.auto_close_after = 0.0
	_card.chars_per_second = 28.0
	if _card.closed_by_accept and RunState.use_continue():
		_continue_result = "continue"
		if change_scene_on_continue:
			get_tree().reload_current_scene.call_deferred()
		return
	_continue_result = "game_over"
	_finish_game()


## 最終面のあと・ゲームオーバー。得点を出してからタイトルへ戻す。
## RunState.reset() は結果を見せた後に呼ぶ（先に呼ぶと得点が消える）。
func _finish_game() -> void:
	Bgm.stop()
	_show_result(_continue_result != "game_over")


func _show_result(cleared: bool) -> void:
	if not show_result_panel:
		_return_to_title()
		return
	if _result_panel == null:
		var packed := load(RESULT_PANEL_SCENE) as PackedScene
		if packed == null:
			push_warning("belt_stage: result_panel.tscn が無い")
			_return_to_title()
			return
		_result_panel = packed.instantiate() as ResultPanel
		add_child(_result_panel)
		_result_panel.closed.connect(_return_to_title, CONNECT_ONE_SHOT)
	_result_panel.show_result(RunState.score, cleared)


func _return_to_title() -> void:
	RunState.reset()
	StageDirector.reset()
	if change_scene_on_continue:
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


## 検証用。出している結果画面。
func result_panel() -> ResultPanel:
	return _result_panel


func continue_result() -> String:
	return _continue_result


func _flash_white(duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(rect, "modulate:a", 0.0, 0.2)
	tween.tween_callback(layer.queue_free)


func _go_next_stage() -> void:
	if next_stage.is_empty():
		_finish_game()
		return
	get_tree().change_scene_to_file.call_deferred(next_stage)


# --- 敵の実体化 ------------------------------------------------------------

## 画面端の外側に敵を出す。side: 1 = 右、-1 = 左。
func _spawn_enemy(scene: PackedScene, side: int) -> Node3D:
	if scene == null or not is_inside_tree() or is_queued_for_deletion() \
			or _enemies_root == null or not is_instance_valid(_enemies_root) \
			or not _enemies_root.is_inside_tree() \
			or _enemies_root.is_queued_for_deletion():
		return null
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return null
	var x := 0.0
	if _camera != null:
		x = (_camera.right_limit() + spawn_margin) if side >= 0 \
			else (_camera.left_limit() - spawn_margin)
	elif _player != null:
		x = _player.global_position.x + float(side) * 8.0
	var z := randf_range(belt_z_min, belt_z_max)
	_enemies_root.add_child(enemy)
	enemy.global_position = Vector3(x, 0.2, z)
	if enemy.has_method("set_belt_bounds"):
		enemy.call("set_belt_bounds", belt_z_min, belt_z_max)
	return enemy


func current_boss() -> Node3D:
	return _boss


## 地面テクスチャを床マテリアルへ貼る。X（床の長さ）方向にタイルし、Z も同じ密度で繰り返す。
## BoxMesh は面ごとに UV が 0..1 なので、uv1_scale で繰り返し数を掛ける。
func _apply_ground_texture() -> void:
	if ground_texture_path.is_empty() or not ResourceLoader.exists(ground_texture_path):
		return
	var floor_mesh := get_node_or_null(floor_mesh_path) as MeshInstance3D
	if floor_mesh == null:
		return
	var texture := load(ground_texture_path) as Texture2D
	if texture == null:
		return
	var box := floor_mesh.mesh as BoxMesh
	var size_x := box.size.x if box != null else (x_max - x_min)
	var size_z := box.size.z if box != null else (belt_z_max - belt_z_min)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_repeat = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.uv1_scale = Vector3(
		maxf(size_x / ground_tile_size, 1.0),
		maxf(size_z / ground_tile_size, 1.0), 1.0)
	# 影は落とすが、床自体は既定のライティングで見せる（背景の板と違い接地感が要る）。
	floor_mesh.set_surface_override_material(0, material)
