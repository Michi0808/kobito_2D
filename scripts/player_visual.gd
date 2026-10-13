class_name PlayerVisual
extends Node2D
## 主人公の絵を動かす。1枚絵を 体・腕（ひじから先）・脚2本・つるはし に分け（art/player/）、
## それぞれを関節で回して 待機・歩行・走行・ジャンプ・滑空・横振り・縦振り を作る（切り絵アニメ）。
## 原点は足元の中心。数値はパーツを切り出したときの座標（art/player/rig.json と同じ）。

const DIR := "res://art/player/"
## 絵の大きさ（パーツは原画の 0.12 倍で書き出してあり、それをさらにこの倍率で表示する）
const GAME_SCALE := 0.6
const PARTS := {
	"body": {"pivot": Vector2(42.24, 132.6), "origin": Vector2(0, 0)},
	"arm": {"pivot": Vector2(8.28, 3.36), "origin": Vector2(-14.16, -61.08)},
	"leg_back": {"pivot": Vector2(11.16, 4.68), "origin": Vector2(-10.2, -23.64)},
	"leg_front": {"pivot": Vector2(10.56, 4.68), "origin": Vector2(9.36, -23.64)},
	"pickaxe": {"pivot": Vector2(22.8, 42.24), "origin": Vector2(0, 0)},
}
## 腕の軸から見た、つるはしを握る位置
const GRIP := Vector2(-2.64, 18.0)
const SWING_TIME := 0.22

enum Move { IDLE, WALK, RUN, RISE, FALL, GLIDE }

var move := Move.IDLE
var facing := 1
var t := 0.0
var swing_t := 0.0
## "side"=横振り（戦闘・横の採掘）, "down"=縦振り（足元を掘る）, "up"=上を掘る
var swing_kind := "side"

var upper: Node2D      # 体と腕（傾ける・上下に揺らす）
var body: Node2D
var arm: Node2D
var pick: Node2D
var leg_back: Node2D
var leg_front: Node2D


func _ready() -> void:
	leg_back = _joint("leg_back", self)
	leg_front = _joint("leg_front", self)
	upper = Node2D.new()
	add_child(upper)
	body = _joint("body", upper)
	arm = _joint("arm", upper)
	pick = _joint("pickaxe", arm)
	pick.position = GRIP
	# 手が柄の手前に来るように、つるはしは腕の絵より先（後ろ）に描く
	arm.move_child(pick, 0)
	_apply_scale()


func _joint(part: String, parent: Node) -> Node2D:
	var j := Node2D.new()
	j.position = PARTS[part]["origin"]
	var s := Sprite2D.new()
	s.texture = load(DIR + part + ".png")
	s.centered = false
	s.position = -PARTS[part]["pivot"]
	j.add_child(s)
	parent.add_child(j)
	return j


func _apply_scale() -> void:
	scale = Vector2(GAME_SCALE * facing, GAME_SCALE)


func set_facing(f: int) -> void:
	if f != facing:
		facing = f
		_apply_scale()


func start_swing(kind: String) -> void:
	swing_kind = kind
	swing_t = SWING_TIME


func is_swinging() -> bool:
	return swing_t > 0.0


func _process(delta: float) -> void:
	t += delta
	swing_t = maxf(swing_t - delta, 0.0)

	var leg_a := 0.0       # 脚の振り（度）
	var bob := 0.0         # 上下の揺れ
	var lean := 0.0        # 体の前傾（度）
	var arm_rest := -12.0  # 振っていないときの腕
	var stretch := 1.0
	match move:
		Move.IDLE:
			stretch = 1.0 + 0.012 * sin(t * 2.4)
			arm_rest = -8.0 + 3.0 * sin(t * 2.4)
		Move.WALK:
			var ph := t * 9.0
			leg_a = 22.0 * sin(ph)
			bob = -absf(sin(ph)) * 3.0
			arm_rest = -12.0 - 14.0 * sin(ph)
		Move.RUN:
			var ph := t * 15.0
			leg_a = 28.0 * sin(ph)
			bob = -absf(sin(ph)) * 5.0
			lean = 7.0
			arm_rest = -30.0 - 30.0 * sin(ph)
		Move.RISE:
			leg_back.rotation_degrees = 18.0
			leg_front.rotation_degrees = -30.0
			arm_rest = -60.0
			stretch = 1.04
		Move.FALL:
			arm_rest = -100.0
		Move.GLIDE:
			# 葉のグライダーを頭の上で持つ
			arm_rest = 175.0
			leg_a = 8.0 * sin(t * 3.0)

	if move != Move.RISE:
		leg_back.rotation_degrees = leg_a
		leg_front.rotation_degrees = -leg_a
	upper.position.y = bob
	upper.rotation_degrees = lean
	upper.scale = Vector2(1.0, stretch)

	if swing_t > 0.0:
		var p := 1.0 - swing_t / SWING_TIME
		# 最初の3割で振りかぶり、残りで一気に振り抜く
		var k := 0.0 if p < 0.3 else ease((p - 0.3) / 0.7, 0.35)
		var from := 0.0
		var to := 0.0
		match swing_kind:
			"side":
				from = 70.0
				to = -105.0
			"down":
				from = 185.0
				to = 300.0
			"up":
				from = -20.0
				to = -175.0
		arm.rotation_degrees = lerpf(from, to, k)
		pick.rotation_degrees = 150.0
	else:
		arm.rotation_degrees = lerpf(arm.rotation_degrees, arm_rest, minf(1.0, delta * 14.0))
		# 持ち歩くときは刃を前に向けて肩に担ぐ
		pick.rotation_degrees = lerpf(pick.rotation_degrees, 115.0, minf(1.0, delta * 14.0))
