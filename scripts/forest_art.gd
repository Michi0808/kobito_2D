class_name ForestArt
extends RefCounted
## 森の手描き素材（art/forest/）の読み込みと、絵に合わせた当たり判定の位置。
## 絵はゲームで表示する大きさの 2 倍で書き出してあり、0.5 倍で表示する（tools/build_forest_art.py）。
## 絵を描き直して形が変わったら、下の数値（絵の中の px）も合わせる。

const DIR := "res://art/forest/"
const SCALE := 0.5

## 枝の足場（platform_branch.png 640×213）：上面の高さと、乗れる左右の範囲
const BRANCH_TOP := 94.0
const BRANCH_BOTTOM := 132.0
const BRANCH_X0 := 16.0
const BRANCH_X1 := 624.0

## 登れる大木（climb_*.png）。元の絵の半分の大きさで書き出してあるので、下の数値は元の絵の px。
## 置くときは「元の絵 1px が画面で何 px か」（k）を決めて climb_sprite() で置く
const CLIMB_EXPORT := 0.5
const TRUNK_SRC_W := 500.0  # 幹の太さ（3枚とも同じ）
const TRUNK_MID_H := 1000.0  # trunk_mid を縦に並べる間隔
const TRUNK_MID_CX := 320.0
const TRUNK_BASE_TOP := Vector2(822, 80)  # 根元の上の切り口の中心
const TRUNK_BASE_BOTTOM := 1204.0  # 根の下端
const TRUNK_TOP_BOTTOM := Vector2(1471, 2463)  # 樹冠の下の切り口の中心
## 枝：cut は根元の切り口（幹の中心に合わせる）、end は乗れる右端、top は上面の線、ref は高さの基準にする上面
const BRANCH_ART := {
	"branch_long": {"cut": 75.0, "end": 1240.0, "ref": 394.0,
		"top": [Vector2(75, 362), Vector2(560, 394), Vector2(900, 390), Vector2(1240, 394)]},
	"branch_short": {"cut": 100.0, "end": 700.0, "ref": 190.0,
		"top": [Vector2(100, 172), Vector2(360, 180), Vector2(600, 200), Vector2(700, 212)]},
}
## 葉の房：実を吊る空の茎の先（左から順）
const LEAF_STEMS := {
	"leaf_cluster_a": [Vector2(324, 500), Vector2(410, 546), Vector2(495, 526)],
	"leaf_cluster_b": [Vector2(282, 408), Vector2(410, 430), Vector2(566, 429), Vector2(724, 407)],
	"leaf_cluster_c": [Vector2(318, 380), Vector2(389, 419), Vector2(450, 418)],
}


## 籠（basket_back / basket_front.png 400×285）
const BASKET_RIM := 180.0  # 左右の縁の高さ
const BASKET_FLOOR := 222.0  # 中の底（実が縁から少し見えるよう、絵の底より浅くしてある）
const BASKET_WALL_L := 14.0
const BASKET_WALL_R := 386.0
const BASKET_BOTTOM := 280.0

## 葉の坂（leaf_ramp.png 360×163）：上面の線（左下から右上へ）と下端
const RAMP_TOP := [
	Vector2(0, 137), Vector2(45, 127), Vector2(90, 111), Vector2(135, 99), Vector2(180, 73),
	Vector2(225, 47), Vector2(270, 27), Vector2(315, 17), Vector2(345, 6),
]
const RAMP_BOTTOM := 158.0

## 岩（rock_01.png 420×153）：上面の線と下端
const ROCK_TOP := [
	Vector2(0, 40), Vector2(26, 14), Vector2(78, 4), Vector2(130, 2), Vector2(200, 14),
	Vector2(280, 22), Vector2(360, 25), Vector2(400, 34), Vector2(420, 60),
]
const ROCK_BOTTOM := 150.0

## 地面の縁（edge_top.png 1024×357）：歩く面にそろえる高さと、土の帯の下端
const EDGE_GROUND := 214.0
const EDGE_BOTTOM := 307.0


static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


## 左上を pos に置く絵
static func sprite(name: String, pos: Vector2, s := SCALE) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(name)
	sp.centered = false
	sp.scale = Vector2(s, s)
	sp.position = pos
	return sp


## 横につないで敷きつめる絵（地面の土・縁）
static func tiled(name: String, rect: Rect2, s := SCALE) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(name)
	sp.centered = false
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(Vector2.ZERO, rect.size / s)
	sp.scale = Vector2(s, s)
	sp.position = rect.position
	return sp


## 絵の中の点の並び（px）を、置いた位置・大きさ・左右反転に合わせて直す
static func points(src: Array, origin: Vector2, s: float, width_px: float, flip := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		var x: float = width_px - p.x if flip else p.x
		out.append(origin + Vector2(x, p.y) * s)
	return out


## 登れる大木のパーツを、元の絵の点 src_pt が pos に来るように置く。k は元の絵 1px の画面上の大きさ
static func climb_sprite(name: String, src_pt: Vector2, pos: Vector2, k: float, flip := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex("climb_" + name)
	sp.centered = false
	sp.flip_h = flip
	var s := k / CLIMB_EXPORT
	sp.scale = Vector2(s, s)
	var src_w := sp.texture.get_width() / CLIMB_EXPORT
	var px := (src_w - src_pt.x) if flip else src_pt.x
	sp.position = pos - Vector2(px, src_pt.y) * k
	return sp
