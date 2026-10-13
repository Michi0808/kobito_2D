extends Node2D
## 根灯りの村（試作では根元の一画だけ）。坑道への入口と、自由に建築できる空き地がある。

const T := Tiles.SIZE
const WIDTH := 70
const GROUND_Y := 16
const ENTRANCE_X := 6
const BUILD_AREA := Rect2i(18, 3, 46, 13)  # x 18〜63, y 3〜15

var map: TileMapLayer
var player: Player
var hud: HUD
var build: BuildSystem


func _ready() -> void:
	Game.level = self
	Game.boss = null

	var sky := Parallax2D.new()
	sky.scroll_scale = Vector2(0.3, 0.5)
	sky.z_index = -20
	add_child(sky)
	var far := Node2D.new()
	far.draw.connect(_draw_far.bind(far))
	sky.add_child(far)

	var tree := Parallax2D.new()
	tree.scroll_scale = Vector2(0.7, 0.85)
	tree.z_index = -15
	add_child(tree)
	var trunk := Node2D.new()
	trunk.draw.connect(_draw_trunk.bind(trunk))
	tree.add_child(trunk)

	map = TileMapLayer.new()
	map.tile_set = Tiles.get_tileset()
	add_child(map)
	for x in range(-1, WIDTH + 1):
		map.set_cell(Vector2i(x, GROUND_Y), 0, Vector2i(Tiles.GROUND, 0))
		for y in range(GROUND_Y + 1, GROUND_Y + 6):
			map.set_cell(Vector2i(x, y), 0, Vector2i(Tiles.DIRT, 0))
	for y in range(-10, GROUND_Y):
		map.set_cell(Vector2i(-1, y), 0, Vector2i(Tiles.LIVING_ROOT, 0))
		map.set_cell(Vector2i(WIDTH, y), 0, Vector2i(Tiles.LIVING_ROOT, 0))
	# 坑道の上の根の張り出し（葉っぱの足場）
	for x in range(10, 15):
		map.set_cell(Vector2i(x, 12), 0, Vector2i(Tiles.LEAF, 0))
	for x in range(2, 6):
		map.set_cell(Vector2i(x, 9), 0, Vector2i(Tiles.LEAF, 0))

	var mod := CanvasModulate.new()
	mod.color = Color(0.95, 0.9, 0.82)
	add_child(mod)

	hud = HUD.new()
	add_child(hud)

	build = BuildSystem.new()
	build.setup(BUILD_AREA, map, hud)
	add_child(build)

	add_child(_npc("バルド", "坑道の下の段は暗い。ランタンを作ってから行け。", Color(0.35, 0.33, 0.3), ENTRANCE_X + 3))
	add_child(_npc("ネリ", "作業台を屋根と左右の壁で囲うと工房になるよ。ランタンはそこで作れる。", Color(0.38, 0.45, 0.58), 22))
	add_child(_npc("ルカ", "おかえり。まずは食べて休みな。", Color(0.55, 0.42, 0.3), 66))

	player = Player.new()
	player.position = Vector2((ENTRANCE_X + 1) * T, GROUND_Y * T - 14)
	add_child(player)
	player.light.enabled = false
	player.set_camera_limits(Rect2(-T, -T * 10, (WIDTH + 2) * T, (GROUND_Y + 14) * T))

	hud.set_hint("移動 A/D　ジャンプ Space（長押しで滑空）　攻撃 J　ダッシュ K　話す・坑道に入る・作業台 E　建築モード B")
	if Game.queued_message == "" and Game.built.is_empty():
		Game.post("根灯りの村。左の坑道で材料を集め、空き地に小屋を建てよう。")


func _npc(n: String, text: String, c: Color, x: int) -> Npc:
	var npc := Npc.new().setup(n, text, c)
	npc.position = Vector2(x * T + T / 2.0, GROUND_Y * T - 13)
	return npc


func on_interact() -> void:
	if Time.get_ticks_msec() - hud.craft_closed_at < 300:
		return
	if absf(player.global_position.x - (ENTRANCE_X * T + T / 2.0)) < 40.0:
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
	# 坑道の入口（黒い母岩に掘られた坑口と支柱）
	var o := Vector2(ENTRANCE_X * T + T / 2.0, GROUND_Y * T)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-34, 0), o + Vector2(-30, -60), o + Vector2(0, -74), o + Vector2(30, -60), o + Vector2(34, 0)]), Color(0.12, 0.1, 0.09))
	draw_rect(Rect2(o + Vector2(-36, -66), Vector2(8, 66)), Color(0.5, 0.34, 0.2))
	draw_rect(Rect2(o + Vector2(28, -66), Vector2(8, 66)), Color(0.5, 0.34, 0.2))
	draw_rect(Rect2(o + Vector2(-40, -72), Vector2(80, 8)), Color(0.45, 0.3, 0.18))
	draw_circle(o + Vector2(-46, -50), 5.0, Color(1.0, 0.72, 0.3))
	draw_circle(o + Vector2(46, -50), 5.0, Color(1.0, 0.72, 0.3))
	draw_line(o + Vector2(-20, 0), o + Vector2(-20, -4), Color(0.4, 0.4, 0.42), 2.0)
	draw_line(o + Vector2(-26, -2), o + Vector2(26, -2), Color(0.4, 0.4, 0.42), 2.0)


func _draw_far(n: Node2D) -> void:
	n.draw_rect(Rect2(-2000, -1200, 6000, 2400), Color(0.55, 0.7, 0.62))
	for i in 9:
		var x := -400.0 + i * 420.0
		n.draw_rect(Rect2(x, -900, 90 + (i % 3) * 30, 1800), Color(0.42, 0.56, 0.5))


func _draw_trunk(n: Node2D) -> void:
	# 世界樹の幹と根（仮の形）。画面の奥に大きくそびえ、左右に空と森が見える
	var c := Color(0.42, 0.32, 0.23)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(420, 560), Vector2(640, -1400), Vector2(1380, -1400), Vector2(1600, 560)]), c)
	for i in 5:
		var x := 700.0 + i * 160.0
		n.draw_polyline(PackedVector2Array([Vector2(x, -1300), Vector2(x + 20, -500), Vector2(x - 15, 100), Vector2(x + 10, 560)]), c.darkened(0.2), 8.0)
	n.draw_colored_polygon(PackedVector2Array([Vector2(150, 560), Vector2(520, 260), Vector2(700, 560)]), c.darkened(0.08))
	n.draw_colored_polygon(PackedVector2Array([Vector2(1350, 560), Vector2(1560, 240), Vector2(1950, 560)]), c.darkened(0.08))
	# 幹の空洞の住まいの灯り
	for i in 5:
		n.draw_circle(Vector2(760 + i * 120, -40 - (i % 2) * 140), 6.0, Color(1.0, 0.75, 0.35))
