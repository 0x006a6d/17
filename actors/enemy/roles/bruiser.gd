extends Enemy
class_name Bruiser

## 中ボス。挙動は通常型と同じで、数値（HP・のけぞり耐性・威力）と体格だけが違う。
## 数値は bruiser.tscn のインスペクタで上書きし、ここでは体格とボスバーの名乗りだけを持つ。

@export_group("Bruiser")
## Model に掛ける拡大率。
@export var model_scale: float = 1.15
## ボスバーに出す名前。
@export var boss_name: String = "大男"
@export_group("")


func _ready() -> void:
	super._ready()
	if _model != null:
		_model.scale = Vector3.ONE * model_scale


func display_name() -> String:
	return boss_name


func is_boss() -> bool:
	return true
