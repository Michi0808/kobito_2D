extends Node2D
## 根灯りの村（試作では根元の一画だけ）。
## 左側は描いた背景絵（坑道の入口・工房・市場）をそのまま使い、右側が自由に建築できる空き地。

const T := Tiles.SIZE
const GROUND_Y := 16
## 背景絵 art/village_base.png の置き方。絵の中の通り道が地面（GROUND_Y）に重なるように合わせてある
const BASE_ART := "res://art/village_base.png"
const BASE_SCALE := 1.0313
const BASE_TOP := -71.0
const BASE_W := 70           # 絵の幅（マス）
## 絵の中の坑道の入口（x 座標）
const ENTRANCE_PX := 476.0
## 空き地は絵の右側
const WIDTH := 112
const BUILD_AREA := Rect2i(72, 3, 38, 13)  # x 72〜109, y 3〜15

var map: TileMapLayer
var player: Player
var hud: HUD
var build: BuildSystem


func _ready() -> void:
	Game.level = self
	Game.boss = null

	# 空き地側の奥に見える森（仮の図形）
	var sky := Parallax2D.new()
	sky.scroll_scale = Vector2(0.4, 0.6)
	sky.z_index = -20
	add_child(sky)
	var far := Node2D.new()
	far.draw.connect(_draw_far.bind(far))
	sky.add_child(far)

	# 村の背景絵
	var base := Sprite2D.new()
	base.texture = load(BASE_ART)
	base.centered = false
	base.scale = Vector2(BASE_SCALE, BASE_SCALE)
	base.position = Vector2(0, BASE_TOP)
	base.z_index = -10
	add_child(base)

	map = TileMapLayer.new()
	map.tile_set = Tiles.get_tileset()
	add_child(map)
	# 絵の部分は絵の中の通り道が地面なので、当たり判定だけ置く
	var floor_body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(BASE_W * T, 6 * T)
	cs.shape = sh
	cs.position = Vector2(BASE_W * T / 2.0, GROUND_Y * T + 3 * T)
	floor_body.add_child(cs)
	add_child(floor_body)
	# 空き地はタイルの地面
	for x in range(BASE_W, WIDTH + 1):
		map.set_cell(Vector2i(x, GROUND_Y), 0, Vector2i(Tiles.GROUND, 0))
		for y in range(GROUND_Y + 1, GROUND_Y + 6):
			map.set_cell(Vector2i(x, y), 0, Vector2i(Tiles.DIRT, 0))
	for y in range(-10, GROUND_Y):
		map.set_cell(Vector2i(-1, y), 0, Vector2i(Tiles.LIVING_ROOT, 0))
		map.set_cell(Vector2i(WIDTH, y), 0, Vector2i(Tiles.LIVING_ROOT, 0))

	hud = HUD.new()
	add_child(hud)

	build = BuildSystem.new()
	build.setup(BUILD_AREA, map, hud)
	add_child(build)

	add_child(_npc("バルド", "坑道の下の段は暗い。ランタンを作ってから行け。", Color(0.35, 0.33, 0.3), ENTRANCE_PX + 110.0))
	add_child(_npc("ネリ", "右の空き地で、作業台を屋根と左右の壁で囲うと工房になるよ。ランタンはそこで作れる。", Color(0.38, 0.45, 0.58), 1010.0))
	add_child(_npc("ルカ", "おかえり。まずは食べて休みな。", Color(0.55, 0.42, 0.3), 1700.0))

	player = Player.new()
	player.position = Vector2(ENTRANCE_PX + 60.0, GROUND_Y * T - 14)
	add_child(player)
	player.light.enabled = false
	player.set_camera_limits(Rect2(0, BASE_TOP, WIDTH * T, 746))

	hud.set_hint("移動 A/D　ジャンプ Space（長押しで滑空）　攻撃 J　ダッシュ K　話す・坑道に入る・作業台 E　建築モード B")
	if Game.queued_message == "" and Game.built.is_empty():
		Game.post("根灯りの村。坑道で材料を集め、右の空き地に小屋を建てよう。")


func _npc(n: String, text: String, c: Color, x: float) -> Npc:
	var npc := Npc.new().setup(n, text, c)
	npc.position = Vector2(x, GROUND_Y * T - 13)
	return npc


func on_interact() -> void:
	if Time.get_ticks_msec() - hud.craft_closed_at < 300:
		return
	if absf(player.global_position.x - ENTRANCE_PX) < 48.0:
		player.controls_locked = true
		Game.goto_mine()
		return
	var bench: Variant = build.bench_near(player.global_position)
	if bench != null:
		if build.is_workshop(bench):
			hud.open_craft()
		else:
			Game.post("この作業台はまだ雨ざらし。屋根と左右の壁で囲うと工房として使える。")


func on_player_down() -> void:
	player.heal_full()
	player.controls_locked = false


func _draw() -> void:
	# 空き地の入口の立て札
	var o := Vector2(BUILD_AREA.position.x * T - 40, GROUND_Y * T)
	draw_rect(Rect2(o + Vector2(-2, -40), Vector2(4, 40)), Color(0.4, 0.28, 0.16))
	draw_rect(Rect2(o + Vector2(-18, -44), Vector2(36, 16)), Color(0.6, 0.45, 0.28))


func _draw_far(n: Node2D) -> void:
	# 空き地の奥の森（仮）。背景絵と色味を合わせた木立と根
	n.draw_rect(Rect2(-2000, -1200, 8000, 2400), Color(0.5, 0.6, 0.5))
	for i in 16:
		var x := -400.0 + i * 340.0
		n.draw_rect(Rect2(x, -900, 110 + (i % 3) * 50, 1800), Color(0.36, 0.3, 0.22))
		n.draw_circle(Vector2(x + 60, -60 + (i % 4) * 30), 140.0, Color(0.33, 0.45, 0.27))
	n.draw_rect(Rect2(-2000, 260, 8000, 500), Color(0.3, 0.36, 0.22))
