class_name MuzzleTip
extends RefCounted

## 武器モデルの銃口（本体の正面方向へ最も突き出た頂点）を測る。
##
## 銃口炎も弾道もここから出るので、本体からの固定オフセットにすると、腕が動く
## 発砲・歩き・走りで絵が銃の先から離れる。プレイヤーと銃の敵で同じ測り方を使う。


## 銃口をモデルのローカル座標で返す。「モデルの +X が銃身」と決め打ちせず、
## そのときの正面向き（水平成分だけを見る）から決める。頂点を総なめするので、
## 装備のたびに1度だけ測り、以後は変換だけで済ませること。
static func measure_local(weapon: Node3D, forward: Vector3) -> Vector3:
	if weapon == null:
		return Vector3.ZERO
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.is_zero_approx():
		flat = Vector3.FORWARD
	var local_forward: Vector3 = (weapon.global_transform.basis.orthonormalized().inverse()
		* flat.normalized())
	var best := Vector3.ZERO
	var best_distance: float = -INF
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				var distance: float = local.dot(local_forward)
				if distance > best_distance:
					best_distance = distance
					best = local
	return best
