extends Resource
class_name SpeakerProfile

## テキストカードの話者（technical-spec §11）。台本の `名前「…」` の名前で引く。
## タイル（通話画面の参加者枠）に出す立ち絵・色と、タイルを置く側を持つ。

enum Side { LEFT, RIGHT }

## 台本に書く名前（`AIニケ「…」` の `AIニケ`）。
@export var speaker_name: String = ""
## タイルに出す表示名。空なら speaker_name。
@export var display_name: String = ""
## 立ち絵（公式三面図など）。リポジトリに含めない資産なので、存在チェックしてから読む。
@export_file("*.png") var portrait_path: String = ""
## 立ち絵から顔として切り出す正方形の範囲（px）。size が 0 なら全体。
@export var portrait_region: Rect2i = Rect2i(0, 0, 0, 0)
## タイルの枠と名前の色（発言中の強調）。
@export var color: Color = Color(0.35, 0.3, 0.6)
## タイルを置く側。文章は反対側に出る。
@export_enum("LEFT", "RIGHT") var side: int = Side.RIGHT


func label() -> String:
	return display_name if not display_name.is_empty() else speaker_name
