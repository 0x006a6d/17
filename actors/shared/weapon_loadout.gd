extends Node
class_name WeaponLoadout

## WeaponHolder と右手指 modifier をまとめて設定する共有装備部品。
## キャラクターモデルを親の _ready() で差し込む敵にも対応するため、装備は deferred で行う。

enum GripProfile { NONE, PISTOL, KATANA }

const WEAPON_GRIP_SCRIPT := preload("res://actors/player/player_weapon_grip.gd")

@export_group("Weapon")
@export var weapon_scene: PackedScene
@export var grip_offset: Vector3 = Vector3.ZERO
@export var grip_rotation: Vector3 = Vector3.ZERO
@export var grip_scale: Vector3 = Vector3.ONE

@export_group("Grip geometry")
@export_enum("None", "Pistol", "Katana") var grip_profile: int = GripProfile.NONE
@export var grip_axis_start: Vector3 = Vector3.ZERO
@export var grip_axis_end: Vector3 = Vector3.ZERO
@export var grip_model_radius: float = 0.0

@export_group("Nodes")
@export var holder_path: NodePath = ^"../WeaponHolder"
@export var weapon_grip_path: NodePath = ^"../WeaponGrip"
@export_group("")

var _holder: WeaponHolder = null
var _weapon_grip: WEAPON_GRIP_SCRIPT = null


func _ready() -> void:
	call_deferred("equip")


func equip() -> void:
	_holder = get_node_or_null(holder_path) as WeaponHolder
	_weapon_grip = get_node_or_null(weapon_grip_path) as WEAPON_GRIP_SCRIPT
	if _holder == null or weapon_scene == null:
		return
	_holder.equip(weapon_scene, grip_offset, grip_rotation, grip_scale)
	if _weapon_grip == null or not _weapon_grip.setup():
		return
	_weapon_grip.set_grip_geometry(_holder.current_weapon(), grip_axis_start,
		grip_axis_end, grip_model_radius)
	match grip_profile:
		GripProfile.PISTOL:
			_weapon_grip.use_pistol_grip()
		GripProfile.KATANA:
			_weapon_grip.use_katana_grip()
		_:
			_weapon_grip.clear_grip()


func current_weapon() -> Node3D:
	return _holder.current_weapon() if _holder != null else null


func has_weapon() -> bool:
	return _holder != null and _holder.has_weapon()


func is_grip_active() -> bool:
	return _weapon_grip != null and _weapon_grip.is_grip_active()
