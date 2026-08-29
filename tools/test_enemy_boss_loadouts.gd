extends Node

## 敵モデル差し替え、面ボス割り当て、共有武器の射撃・斬撃を headless で検証する。
##   godot --path . --headless res://tools/test_enemy_boss_loadouts.tscn

const TEST_STAGE: String = "res://levels/belt_test.tscn"
const BASE_ENEMY: String = "res://actors/enemy/enemy.tscn"
const GRUNT_B: String = "res://actors/enemy/roles/grunt_b.tscn"
const GRUNT_C: String = "res://actors/enemy/roles/grunt_c.tscn"
const RUSHER: String = "res://actors/enemy/roles/rusher.tscn"
const STAGE_1_BOSS: String = "res://actors/enemy/bosses/stage_1_boss.tscn"
const STAGE_2_BOSS: String = "res://actors/enemy/bosses/stage_2_boss.tscn"
const STAGE_3_BOSS: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const STAGE_4_BOSS: String = "res://actors/enemy/bosses/stage_4_boss.tscn"
const NIKE_BOSS: String = "res://actors/boss/nike.tscn"
const DEATH_MOTION: String = "res://assets/motions/mixamo_death_headshot.fbx"
const MAX_FRAMES: int = 1200
const SETUP_FRAMES: int = 12
const EXPECTED_GUN_DAMAGE: float = 5000.0
## 4面ボスの拳銃。主人公の拳銃（player_weapon.gd の gun_damage）と同じ値。
const EXPECTED_PISTOL_DAMAGE: float = 4500.0
const DAMAGE_EPSILON: float = 0.01
const ROOT_MOTION_EPSILON: float = 0.001
const RETAINED_MODEL_NUMBERS: PackedInt32Array = [1, 8, 28]

const STAGE_BOSS_PATHS: PackedStringArray = [
	"res://levels/stage_1.tscn",
	"res://levels/stage_2.tscn",
	"res://levels/stage_3.tscn",
]
const EXPECTED_BOSS_SCENES: PackedStringArray = [
	STAGE_1_BOSS,
	STAGE_2_BOSS,
	STAGE_3_BOSS,
]
const BOSS_SCENES: PackedStringArray = [
	STAGE_1_BOSS,
	STAGE_2_BOSS,
	STAGE_3_BOSS,
	STAGE_4_BOSS,
]
const EXPECTED_MODELS: PackedStringArray = [
	"res://assets/characters/mixamo_ch35.fbx",
	"res://assets/characters/mixamo_swat.fbx",
	"res://assets/characters/mixamo_ch15.fbx",
	"res://assets/characters/mixamo_ch16_boss.fbx",
]
## 2面（刀）・3面（ライフル）・4面（拳銃）の順。1面は素手。
## 3面はライフルに変更した（Shooter Pack のモーションに合わせた。asset-credits 参照）。
## 4面は主人公と同じ拳銃を持たせ、盾を放したあとは撃って戦う。
const EXPECTED_WEAPONS: PackedStringArray = [
	"res://assets/weapons/katana.glb",
	"res://assets/weapons/rifle.glb",
	"res://assets/weapons/pistol.glb",
]
const ZOMBIE: String = "res://actors/enemy/roles/zombie.tscn"
const ZOMBIE_B_PINK: String = "res://actors/enemy/roles/zombie_b_pink.tscn"
const ZOMBIE_C_YELLOW: String = "res://actors/enemy/roles/zombie_c_yellow.tscn"
## 色違いの雑魚（2面以降に混ぜる）。
const PALETTE_VARIANTS: PackedStringArray = [
	"res://actors/enemy/roles/grunt_a_black.tscn",
	"res://actors/enemy/roles/grunt_b_pink.tscn",
	"res://actors/enemy/roles/grunt_c_yellow.tscn",
	"res://actors/enemy/roles/rusher_red.tscn",
]
const ZOMBIE_ESCORT: String = "res://actors/enemy/roles/zombie_escort.tscn"
const FINAL_GUARD: String = "res://actors/enemy/roles/final_guard.tscn"
const NIKE_BLANK: String = "res://actors/enemy/roles/nike_blank.tscn"
const ZOMBIE_IDLE: String = "res://assets/motions/mixamo_zombie_idle.fbx"
const ZOMBIE_WALK: String = "res://assets/motions/mixamo_zombie_walk.fbx"
const ZOMBIE_ATTACK: String = "res://assets/motions/mixamo_zombie_attack.fbx"
## Ch18 は With Skin の1本から見た目と攻撃モーションの両方を取る。
const CH18: String = "res://assets/characters/mixamo_ch18.fbx"
## 通常型の攻撃クリップ（enemy.tscn の既定）。5面の増援はこれを使う。
const NORMAL_ATTACK: String = "res://assets/motions/mixamo_cross_punch.fbx"

var _pass: int = 0
var _fail: int = 0
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _player_health: Health = null
var _gun_boss: Node3D = null
var _pistol_boss: Node3D = null
var _gun_start_hp: float = 0.0
var _pistol_start_hp: float = 0.0
var _shots: int = 0
var _shot_hit: Node3D = null
var _pistol_shots: int = 0
var _pistol_shot_hit: Node3D = null


func _ready() -> void:
	print("=== 敵・ボス差し替え／武器 検証開始 ===")
	RunState.reset()
	_check_static_assignments()
	_stage = (load(TEST_STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null(^"Player") as Node3D
	if _player == null:
		_check("検証ステージから Player と Health を取得できる", false)
		_finish()
		return
	_player_health = _player.get_node_or_null(^"Health") as Health
	if _player_health == null:
		_check("検証ステージから Player と Health を取得できる", false)
		_finish()
		return
	# ボスの威力を厳密に見るので、この検証では端数の揺らぎを切る。
	_player_health.damage_variance = 0.0
	for node_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy: Node3D = _stage.get_node_or_null(NodePath(node_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(50.0, 0.2, 0.0)
	_start_gun_test()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_check("全ケースが制限フレーム内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	var local_frame: int = _frames - _phase_started
	match _phase:
		0:
			if local_frame == SETUP_FRAMES:
				_check_loadout(_gun_boss, "3面ボスの銃")
			if _player_health.current_hp() < _gun_start_hp:
				var applied: float = _gun_start_hp - _player_health.current_hp()
				_check("3面ボスが共有 HitscanGun でプレイヤーを撃つ", _shots >= 1
					and _shot_hit == _player)
				_check("3面ボスの射撃ダメージが設定値どおり (%.1f)" % applied,
					absf(applied - EXPECTED_GUN_DAMAGE) <= DAMAGE_EPSILON)
				_start_pistol_test()
			elif local_frame > 480:
				_check("3面ボスが8秒以内に射撃する", false)
				_start_pistol_test()
		1:
			if local_frame == SETUP_FRAMES:
				_check_loadout(_pistol_boss, "4面ボスの拳銃")
			if _player_health.current_hp() < _pistol_start_hp:
				var applied: float = _pistol_start_hp - _player_health.current_hp()
				_check("4面ボスが盾を放したあと共有 HitscanGun で撃つ",
					_pistol_shots >= 1 and _pistol_shot_hit == _player)
				_check("4面ボスの射撃ダメージが主人公の拳銃と同じ (%.1f)" % applied,
					absf(applied - EXPECTED_PISTOL_DAMAGE) <= DAMAGE_EPSILON)
				_finish()
			elif local_frame > 480:
				_check("4面ボスが8秒以内に射撃する", false)
				_finish()


func _check_static_assignments() -> void:
	var retained_enemy_scenes: PackedStringArray = [BASE_ENEMY, RUSHER, GRUNT_B]
	var retained_models: PackedStringArray = [
		"res://assets/characters/mixamo_ch01.fbx",
		"res://assets/characters/mixamo_ch08.fbx",
		"res://assets/characters/mixamo_ch28.fbx",
	]
	var normal_max_hp: float = 0.0
	for index: int in range(retained_enemy_scenes.size()):
		var retained: Node = (load(retained_enemy_scenes[index]) as PackedScene).instantiate()
		_check("既存雑魚 ch%02d の割り当てを維持" % RETAINED_MODEL_NUMBERS[index],
			_resource_path(retained.get("model_scene")) == retained_models[index])
		if index == 0:
			var normal_health: Health = retained.get_node_or_null(^"Health") as Health
			normal_max_hp = normal_health.max_hp if normal_health != null else 0.0
		retained.free()

	var grunt: Node = (load(GRUNT_C) as PackedScene).instantiate()
	_check("追加雑魚が ch06 を使う", _resource_path(grunt.get("model_scene"))
		== "res://assets/characters/mixamo_ch06.fbx")
	grunt.free()

	for index: int in range(BOSS_SCENES.size()):
		var boss: Node = (load(BOSS_SCENES[index]) as PackedScene).instantiate()
		_check("%d面ボスのモデル割り当て" % (index + 1),
			_resource_path(boss.get("model_scene")) == EXPECTED_MODELS[index])
		var animator: NpcAnimator = boss.get_node_or_null(^"Animator") as NpcAnimator
		_check("%d面ボスの死亡が共通 headshot" % (index + 1), animator != null
			and _resource_path(animator.clip_down) == DEATH_MOTION)
		_check("%d面ボスに消滅前の点滅部品がある" % (index + 1),
			boss.get_node_or_null(^"DespawnBlink") is ModelBlink)
		var boss_health: Health = boss.get_node_or_null(^"Health") as Health
		_check("%d面ボスは雑魚より高HP" % (index + 1), boss_health != null
			and boss_health.max_hp > normal_max_hp)
		boss.free()

	for index: int in range(STAGE_BOSS_PATHS.size()):
		var stage_root: Node = (load(STAGE_BOSS_PATHS[index]) as PackedScene).instantiate()
		var trigger: BossTrigger = stage_root.get_node_or_null(^"BossTrigger") as BossTrigger
		_check("%d面 BossTrigger が指定ボスを出す" % (index + 1), trigger != null
			and _resource_path(trigger.boss_scene) == EXPECTED_BOSS_SCENES[index])
		# 色違い（grunt_c_yellow）も同じ ch06 なので、どちらかが居ればよい。
		_check("%d面の波に追加雑魚 ch06 がいる" % (index + 1),
			_stage_contains_enemy(stage_root, GRUNT_C)
			or _stage_contains_enemy(stage_root, ZOMBIE_C_YELLOW)
			or _stage_contains_enemy(stage_root,
				"res://actors/enemy/roles/grunt_c_yellow.tscn"))
		stage_root.free()

	for index: int in range(EXPECTED_WEAPONS.size()):
		var armed_boss: Node = (load(BOSS_SCENES[index + 1]) as PackedScene).instantiate()
		var loadout: WeaponLoadout = armed_boss.get_node_or_null(^"WeaponLoadout") \
			as WeaponLoadout
		_check("%d面ボスの武器割り当て" % (index + 2), loadout != null
			and _resource_path(loadout.weapon_scene) == EXPECTED_WEAPONS[index])
		armed_boss.free()

	var stage4: Node = (load("res://levels/stage_4.tscn") as PackedScene).instantiate()
	var placed_stage4: Node = stage4.get_node_or_null(^"Shielder")
	_check("4面の配置済みボスが ch16_boss", placed_stage4 != null
		and _resource_path(placed_stage4.get("model_scene")) == EXPECTED_MODELS[3])
	_check("4面の波にゾンビがいる", _stage_contains_enemy(stage4, ZOMBIE)
		and _stage_contains_enemy(stage4, ZOMBIE_B_PINK)
		and _stage_contains_enemy(stage4, ZOMBIE_C_YELLOW))
	var escorts: Array = stage4.get("boss_escorts")
	var escort_paths: PackedStringArray = PackedStringArray()
	for escort: PackedScene in escorts:
		escort_paths.append(_resource_path(escort))
	_check("4面のボス戦に Ch30 のゾンビが加わる",
		escort_paths.has(ZOMBIE_ESCORT))
	_check("4面のボス戦に雑魚のゾンビも加わる", escort_paths.has(ZOMBIE))
	stage4.free()

	_check_zombie_clips()
	_check_palette_variants()

	var stage5: Node = (load("res://levels/stage_5.tscn") as PackedScene).instantiate()
	var stage5_trigger: BossTrigger = stage5.get_node_or_null(^"BossTrigger") as BossTrigger
	_check("5面ボス割り当ては既存ニケのまま", stage5_trigger != null
		and _resource_path(stage5_trigger.boss_scene) == NIKE_BOSS)
	stage5.free()
	var nike: Node = (load(NIKE_BOSS) as PackedScene).instantiate()
	var nike_melee: Node = nike.get_node_or_null(^"PlayerMelee")
	_check("最終ボスの死亡も共通 headshot", nike_melee != null
		and String(nike_melee.get("down_scene")) == DEATH_MOTION)
	_check("最終ボスにも消滅前の点滅部品がある",
		nike.get_node_or_null(^"DespawnBlink") is ModelBlink)
	nike.free()

	var stage5_adds: Node = (load("res://levels/stage_5.tscn") as PackedScene).instantiate()
	var adds: Array = stage5_adds.get("adds_scenes")
	var adds_paths: PackedStringArray = PackedStringArray()
	for add: PackedScene in adds:
		adds_paths.append(_resource_path(add))
	_check("5面の増援がラスボスを守る敵とニケ素体の2種",
		adds_paths.has(FINAL_GUARD) and adds_paths.has(NIKE_BLANK))
	stage5_adds.free()


## 色違いの雑魚。PaletteSwap が付いていて、2面以降の波に混ざっている。
func _check_palette_variants() -> void:
	for path: String in PALETTE_VARIANTS:
		var variant: Node = (load(path) as PackedScene).instantiate()
		var swap: Node = variant.get_node_or_null(^"PaletteSwap")
		_check("%s に PaletteSwap が付く" % path.get_file(), swap is PaletteSwap)
		variant.free()
	for index: int in range(2, 4):
		var stage_root: Node = (load("res://levels/stage_%d.tscn" % index)
			as PackedScene).instantiate()
		var found: int = 0
		for path: String in PALETTE_VARIANTS:
			if _stage_contains_enemy(stage_root, path):
				found += 1
		_check("%d面の波に色違いが %d 種いる" % [index, found], found >= 3)
		stage_root.free()


## 追加したゾンビ系のクリップ割り当て。歩き・攻撃だけを差し替え、死亡は共通のまま。
func _check_zombie_clips() -> void:
	var zombie: Node = (load(ZOMBIE) as PackedScene).instantiate()
	var animator: NpcAnimator = zombie.get_node_or_null(^"Animator") as NpcAnimator
	_check("ゾンビの歩きが Ch30 のゾンビ歩行", animator != null
		and _resource_path(animator.clip_walk) == ZOMBIE_WALK
		and _resource_path(animator.clip_run) == ZOMBIE_WALK)
	_check("ゾンビの待機が Y Bot のゾンビ待機", animator != null
		and _resource_path(animator.clip_idle) == ZOMBIE_IDLE)
	_check("ゾンビの攻撃が Ch30 のゾンビ攻撃", animator != null
		and _resource_path(animator.clip_attack) == ZOMBIE_ATTACK)
	_check("ゾンビの死亡は共通 headshot のまま", animator != null
		and _resource_path(animator.clip_down) == DEATH_MOTION)
	_check("ゾンビの見た目は他の面と同じ ch01",
		_resource_path(zombie.get("model_scene"))
		== "res://assets/characters/mixamo_ch01.fbx")
	zombie.free()

	var escort: Node = (load(ZOMBIE_ESCORT) as PackedScene).instantiate()
	_check("ボス戦に加わるゾンビが ch30", _resource_path(escort.get("model_scene"))
		== "res://assets/characters/mixamo_ch30.fbx")
	escort.free()

	var guard: Node = (load(FINAL_GUARD) as PackedScene).instantiate()
	var guard_animator: NpcAnimator = guard.get_node_or_null(^"Animator") as NpcAnimator
	_check("ラスボスを守る敵が Ch18 の見た目", _resource_path(guard.get("model_scene")) == CH18)
	# ゾンビ状態は4面だけ。5面の増援は見た目だけ固有で、攻撃は通常型と同じ。
	_check("ラスボスを守る敵の攻撃は通常型のまま", guard_animator != null
		and _resource_path(guard_animator.clip_attack) == NORMAL_ATTACK)
	guard.free()

	var blank: Node = (load(NIKE_BLANK) as PackedScene).instantiate()
	var blank_animator: NpcAnimator = blank.get_node_or_null(^"Animator") as NpcAnimator
	_check("ニケ素体の攻撃は通常型のまま", blank_animator != null
		and _resource_path(blank_animator.clip_attack) == NORMAL_ATTACK)
	_check("ニケ素体が VRM を使い ToonSkin を掛けない",
		_resource_path(blank.get("model_scene")) == "res://assets/vrm/nikechan_player.vrm"
		and not bool(blank.get("toon_skin")))
	_check("ニケ素体にヘアピン切りと白塗りが付く",
		blank.get_node_or_null(^"NikeSkin") is NikeSkin
		and blank.get_node_or_null(^"BlankSkin") is BlankSkin)
	blank.free()


func _start_gun_test() -> void:
	_player.global_position = Vector3(4.0, 0.2, 0.0)
	_player_health.revive()
	_gun_start_hp = _player_health.current_hp()
	_gun_boss = (load(STAGE_3_BOSS) as PackedScene).instantiate() as Node3D
	_gun_boss.set("spawn_walk_in", 0.0)
	_stage.add_child(_gun_boss)
	_gun_boss.global_position = Vector3(9.0, 0.2, 0.0)
	_gun_boss.call("set_belt_bounds", -1.5, 1.5)
	var gun: HitscanGun = _gun_boss.get_node_or_null(^"HitscanGun") as HitscanGun
	if gun != null:
		gun.shot_fired.connect(func(_from: Vector3, _to: Vector3, hit: Node3D) -> void:
			_shots += 1
			_shot_hit = hit)
	_phase = 0
	_phase_started = _frames


## 盾を持たせずに出す（人質の居ない検証ステージなので、そのまま射撃へ入る）。
func _start_pistol_test() -> void:
	if _gun_boss != null and is_instance_valid(_gun_boss):
		_gun_boss.set_physics_process(false)
		_gun_boss.queue_free()
	_player_health.revive()
	_pistol_start_hp = _player_health.current_hp()
	_player.global_position = Vector3(4.0, 0.2, 0.0)
	_pistol_boss = (load(STAGE_4_BOSS) as PackedScene).instantiate() as Node3D
	_pistol_boss.set("grab_on_ready", false)
	_pistol_boss.set("guard_enabled", false)
	_stage.add_child(_pistol_boss)
	_pistol_boss.global_position = Vector3(9.0, 0.2, 0.0)
	_pistol_boss.call("set_belt_bounds", -1.5, 1.5)
	var gun: HitscanGun = _pistol_boss.get_node_or_null(^"HitscanGun") as HitscanGun
	if gun != null:
		gun.shot_fired.connect(func(_from: Vector3, _to: Vector3, hit: Node3D) -> void:
			_pistol_shots += 1
			_pistol_shot_hit = hit)
	_phase = 1
	_phase_started = _frames


func _check_loadout(boss: Node3D, label: String) -> void:
	var loadout: WeaponLoadout = boss.get_node_or_null(^"WeaponLoadout") as WeaponLoadout
	_check("%sモデルが右手へ装着済み" % label, loadout != null and loadout.has_weapon())
	_check("%sで右手指modifierが有効" % label,
		loadout != null and loadout.is_grip_active())
	var animator: NpcAnimator = boss.get_node_or_null(^"Animator") as NpcAnimator
	var down_drift: float = animator.clip_horizontal_drift(NpcAnimator.Clip.DOWN) \
		if animator != null else -1.0
	print("[root_motion] %s death_headshot=%.3fm" % [label, down_drift])
	_check("%sの登録済み死亡クリップは水平移動0m" % label,
		down_drift >= 0.0 and down_drift <= ROOT_MOTION_EPSILON)


func _resource_path(value: Variant) -> String:
	var resource: Resource = value as Resource
	return resource.resource_path if resource != null else ""


func _stage_contains_enemy(stage_root: Node, enemy_scene_path: String) -> bool:
	for child: Node in stage_root.get_children():
		var lock_point: LockPoint = child as LockPoint
		if lock_point == null:
			continue
		for wave: WaveSpec in lock_point.waves:
			if wave != null and _resource_path(wave.enemy_scene) == enemy_scene_path:
				return true
	return false


func _check(label: String, ok: bool) -> void:
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
