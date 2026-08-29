class_name WaveSpec
extends Resource

## 画面ロック 1 回に出す波 1 つ分の指定（technical-spec §8.4）。LockPoint が順に消化する。

## 出す敵のシーン（enemy.tscn か roles/*.tscn）。
@export var enemy_scene: PackedScene
## 出す数。
@export var count: int = 2
## 出す側。0 = 左右交互、1 = 画面右、-1 = 画面左。
@export_range(-1, 1) var side: int = 0
## 前の波が全滅してからこの波を出し始めるまでの秒数。
@export var delay: float = 0.4
## 同じ波の中で 1 体ずつ出す間隔（秒）。
@export var spacing: float = 0.5
