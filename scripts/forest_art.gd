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

## 枝の根元の切り株（thin_branch_base.png 480×387）：枝をつなぐ口の中心と、地面に着く下端
const STUMP_SOCKET := Vector2(470.0, 196.0)
const STUMP_BOTTOM := 380.0

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
