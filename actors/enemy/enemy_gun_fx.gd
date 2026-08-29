extends PlayerGunFx
class_name EnemyGunFx

## 敵の銃撃表示。プレイヤーの `PlayerGunFx` を土台にして、**銃口炎の向きだけ**を
## 撃った向きへ合わせる。プレイヤー側の見た目は変えない（あちらは水平固定のまま）。
##
## 元の `_spawn_muzzle_flash()` は向きに `facing`（±X）しか使わないため、銃口炎は
## 常に水平に出る。弾道は `from → to` に沿って傾くので、両者が食い違う。敵は銃を
## 斜めに構えるので、この食い違いが目に付く。
##
## 銃身そのものの向き（構えの傾き）ではなく**弾の向き**に合わせている。銃身と弾の
## 向きは一致していない（実測で 7 度前後ずれる。銃身はやや上、弾は胸へ向けて下）。
## 銃口炎と弾道を揃える方が、絵として破綻しない。

## 直前に撃った向き。`play_shot()` で受け取り、銃口炎の回転に使う。
var _shot_direction: Vector3 = Vector3.ZERO


func play_shot(from: Vector3, to: Vector3, hit_body: Node3D, facing: int,
		weapon: Node3D) -> void:
	_shot_direction = to - from
	super.play_shot(from, to, hit_body, facing, weapon)


## 元の処理で銃口炎を出したあと、追加されたノードだけを撃った向きへ回す。
## 名前で拾わないのは、同じ名前のノードが同時に複数ある場合に取り違えるため。
func _spawn_muzzle_flash(position: Vector3, facing: int) -> void:
	var before: int = get_child_count()
	super._spawn_muzzle_flash(position, facing)
	var tilt: float = _flash_tilt(facing)
	if is_zero_approx(tilt):
		return
	for index: int in range(before, get_child_count()):
		var anchor := get_child(index) as Node3D
		if anchor != null:
			anchor.rotation.z += tilt


## 銃口炎に掛ける回転（ラジアン）。元の処理は facing<0 のとき既に PI 回してあるので、
## その分を差し引いた「水平からのずれ」だけを返す。
func _flash_tilt(facing: int) -> float:
	var direction := Vector3(_shot_direction.x, _shot_direction.y, 0.0)
	if direction.is_zero_approx():
		return 0.0
	var angle: float = atan2(direction.y, direction.x)
	return angle - (PI if facing < 0 else 0.0)
