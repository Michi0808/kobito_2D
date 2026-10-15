class_name ForestLevel
extends Node2D
## ベリーの森（地上の採取場）。村の右端の道から入る。
## 太い茨の枝が足場になっていて、枝には木苺が実っている。実を叩くか、乗っている枝を下攻撃で揺らすと落ちる。
## 落ちた実は体当たりで転がし、葉の坂を押し上げたり上から落としたりして籠に入れる。籠に入った実が収穫になる。
##
## 絵は art/forest/ の手描き素材（作り方は tools/build_forest_art.py）。
## 試作なので配置は手で決めた一場面。あとで地上の他の場所と同じく部屋テンプレートからの生成にする。

const ITEM_WALL := 16  # 籠の壁と底。実だけが当たり、主人公はすり抜ける
const WIDTH := 3200.0
const GROUND := 0.0
const ENTRANCE_X := 70.0
## 枝の段の高さ。主人公のジャンプ（約 96px）で一段ずつ登れる間隔
const TIER := [-80.0, -165.0, -250.0, -335.0]
const STUMP_SCALE := 0.38

var player: Player
var hud: HUD
var branches: Array = []  # {x0, x1, top, sprite, berries}
var baskets: Array = []  # {area, count}
var world: Node2D  # 地形・枝・実を入れる
var unripe_noted := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.level = self
	Game.boss = null
	Game.play_bgm(Game.FOREST_BGM)
	rng.seed = 7

	_build_backdrop()
	world = Node2D.new()
	add_child(world)
	_build_ground()

	# 入口から右へ：岩 → 茨の群れ（籠A）→ 開けた所 → 茨の群れ（籠B）→ 岩
	_rock(300.0)
	_bush(470.0, "mid_bush_01", 0.9)
	_bush(1020.0, "mid_bush_02", 0.85)
	_stump(560.0, false)
	_branch(734.0, TIER[0], 320.0, false, [[0.3, "black_m"], [0.55, "black_unripe"], [0.82, "black_s"]])
	_branch(960.0, TIER[1], 290.0, true, [[0.25, "black_l"], [0.62, "black_m"]])
	_branch(1260.0, TIER[2], 300.0, false, [[0.2, "black_m"], [0.45, "black_m"], [0.7, "black_s"], [0.9, "red"]])
	_branch(880.0, TIER[3], 260.0, true, [[0.3, "red"], [0.6, "red_unripe"], [0.85, "red"]])
	_ramp(1138.0, false)
	_basket(1300.0)
	_ground_berry(660.0, "straw")

	_bush(1980.0, "mid_bush_02", 0.9)
	_bush(2480.0, "mid_bush_01", 0.85)
	_stump(2420.0, true)
	_branch(2110.0, TIER[0], 318.0, true, [[0.2, "black_m"], [0.45, "black_s"], [0.72, "black_l"]])
	_branch(1900.0, TIER[1], 280.0, false, [[0.3, "red"], [0.7, "red"]])
	_branch(2160.0, TIER[2], 290.0, true, [[0.3, "black_m"], [0.5, "black_unripe"], [0.75, "black_m"]])
	_branch(2000.0, TIER[3], 250.0, false, [[0.5, "red"], [0.8, "black_l"]])
	_ramp(2548.0, false)
	_basket(2710.0)
	_ground_berry(1750.0, "straw")
	_rock(3000.0)

	_build_foreground()
	_entrance_sign()

	player = Player.new()
	player.position = Vector2(ENTRANCE_X + 80.0, GROUND - Player.BODY.y / 2.0)
	add_child(player)
	player.light.enabled = false
	player.set_camera_limits(Rect2(0, -640, WIDTH, 810))

	hud = HUD.new()
	add_child(hud)
	hud.set_hint("歩く A/D　ジャンプ Space　攻撃 J（実を叩く・W/Sで上下・枝の上で S+J で揺らす）　ダッシュ K で体当たり　村へ戻る 入口で E")
	if Game.queued_message == "":
		Game.post("ベリーの森。枝の実を叩いて落とし、体当たりで転がして籠に入れよう。")


# ---- 地形 ----

func _static(layer: int) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	world.add_child(b)
	return b


func _rect_shape(body: StaticBody2D, r: Rect2, one_way := false) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)


func _build_ground() -> void:
	var s := ForestArt.SCALE
	var ground := _static(1)
	_rect_shape(ground, Rect2(-200, GROUND, WIDTH + 400, 400))
	_rect_shape(ground, Rect2(-60, -1200, 60, 1300))
	_rect_shape(ground, Rect2(WIDTH, -1200, 60, 1300))
	var fill := ForestArt.tiled("ground_texture", Rect2(-200, GROUND + 30, WIDTH + 400, 400), 0.4)
	fill.z_index = -1
	world.add_child(fill)
	var edge_h := 357.0 * s
	var edge := ForestArt.tiled("edge_top", Rect2(-200, GROUND - ForestArt.EDGE_GROUND * s, WIDTH + 400, edge_h))
	edge.z_index = -1
	world.add_child(edge)


func _polygon_body(top: PackedVector2Array, bottom_y: float, layer: int) -> void:
	var poly := PackedVector2Array(top)
	poly.append(Vector2(top[top.size() - 1].x, bottom_y))
	poly.append(Vector2(top[0].x, bottom_y))
	var body := _static(layer)
	var cp := CollisionPolygon2D.new()
	cp.polygon = poly
	body.add_child(cp)


## 岩：地面に置く、乗れる障害物
func _rock(x: float) -> void:
	var s := ForestArt.SCALE
	var origin := Vector2(x, GROUND + 6.0 - ForestArt.ROCK_BOTTOM * s)
	var sp := ForestArt.sprite("rock_01", origin)
	world.add_child(sp)
	_polygon_body(ForestArt.points(ForestArt.ROCK_TOP, origin, s, 420.0), GROUND + 4.0, 1)


## 葉の坂：籠の縁まで実を押し上げる。主人公も登れる
func _ramp(x: float, flip: bool) -> void:
	var s := ForestArt.SCALE
	var origin := Vector2(x, GROUND + 2.0 - ForestArt.RAMP_BOTTOM * s)
	var sp := ForestArt.sprite("leaf_ramp", origin)
	sp.flip_h = flip
	sp.z_index = 1
	world.add_child(sp)
	var top := ForestArt.points(ForestArt.RAMP_TOP, origin, s, 360.0, flip)
	if flip:
		top.reverse()
	# 坂のふもとは地面から段差なく続ける
	if flip:
		top.append(Vector2(top[top.size() - 1].x + 14.0, GROUND))
	else:
		top.insert(0, Vector2(top[0].x - 14.0, GROUND))
	_polygon_body(top, GROUND + 2.0, 1)


## 茨の茂み（枝の後ろに見える大きな株）
func _bush(x: float, name: String, sc: float) -> void:
	var sp := ForestArt.sprite(name, Vector2.ZERO, sc)
	sp.position = Vector2(x, GROUND + 30.0 - sp.texture.get_height() * sc)
	sp.modulate = Color(0.6, 0.7, 0.6)
	sp.z_index = -5
	world.add_child(sp)


## 枝の根元の切り株（見た目だけ）。枝はこの口から伸びているように置く
func _stump(x: float, flip: bool) -> void:
	var s := STUMP_SCALE
	var sp := ForestArt.sprite("thin_branch_base", Vector2(x, GROUND + 6.0 - ForestArt.STUMP_BOTTOM * s), s)
	sp.flip_h = flip
	sp.z_index = -3
	world.add_child(sp)


## 枝の足場。x は乗れる範囲の左端、top は上面の高さ。berries は [枝の上の位置 0〜1, 種類]
func _branch(x: float, top: float, length: float, flip: bool, berries: Array) -> void:
	var s := length / (ForestArt.BRANCH_X1 - ForestArt.BRANCH_X0)
	var sp := ForestArt.sprite("platform_branch", Vector2(x - ForestArt.BRANCH_X0 * s, top - ForestArt.BRANCH_TOP * s), s)
	sp.flip_h = flip
	sp.z_index = -2
	world.add_child(sp)
	var body := _static(1)
	_rect_shape(body, Rect2(x, top, length, 10.0), true)
	var b := {"x0": x, "x1": x + length, "top": top, "sprite": sp, "berries": []}
	var under := top + (ForestArt.BRANCH_BOTTOM - ForestArt.BRANCH_TOP) * s - 4.0
	for e in berries:
		var bx: float = x + length * float(e[0])
		var berry := Berry.new().setup(e[1], true, rng)
		var stem_len := 8.0 + berry.radius * 0.3
		berry.position = Vector2(bx, under + stem_len + berry.radius * 0.8)
		berry.branch = b
		var stem := Sprite2D.new()
		stem.texture = ForestArt.tex("fruit_stem")
		var ss := (stem_len + berry.radius * 0.4) / stem.texture.get_height()
		stem.scale = Vector2(ss, ss)
		stem.centered = false
		stem.position = Vector2(bx - stem.texture.get_width() * ss / 2.0, under)
		stem.z_index = -1
		world.add_child(stem)
		berry.stem = stem
		world.add_child(berry)
		b["berries"].append(berry)
	branches.append(b)


## 地面に生っている実（野苺）
func _ground_berry(x: float, kind: String) -> void:
	var berry := Berry.new().setup(kind, false, rng)
	berry.position = Vector2(x, GROUND - berry.radius)
	world.add_child(berry)


## 籠：奥の絵と手前の絵で実を挟む。壁と底は実にだけ当たる
func _basket(x: float) -> void:
	var s := ForestArt.SCALE
	var origin := Vector2(x, GROUND + 4.0 - ForestArt.BASKET_BOTTOM * s)
	var back := ForestArt.sprite("basket_back", origin)
	back.z_index = -1
	world.add_child(back)
	var front := ForestArt.sprite("basket_front", origin)
	front.z_index = 4
	world.add_child(front)

	var wl := origin.x + ForestArt.BASKET_WALL_L * s
	var wr := origin.x + ForestArt.BASKET_WALL_R * s
	var rim := origin.y + ForestArt.BASKET_RIM * s
	var floor_y := origin.y + ForestArt.BASKET_FLOOR * s
	var walls := _static(ITEM_WALL)
	_rect_shape(walls, Rect2(wl - 3.0, rim, 6.0, floor_y - rim + 6.0))
	_rect_shape(walls, Rect2(wr - 3.0, rim, 6.0, floor_y - rim + 6.0))
	_rect_shape(walls, Rect2(wl, floor_y, wr - wl, 6.0))

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Berry.LAYER
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(wr - wl - 8.0, floor_y - rim + 6.0)
	cs.shape = sh
	cs.position = Vector2((wl + wr) / 2.0, (rim + floor_y) / 2.0 - 3.0)
	area.add_child(cs)
	world.add_child(area)
	baskets.append({"area": area, "count": 0})


# ---- 背景・前景 ----

func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.42, 0.3)
	bg.position = Vector2(-1000, -2000)
	bg.size = Vector2(WIDTH + 2000, 4000)
	bg.z_index = -30
	add_child(bg)

	# 遠景：森の奥。ゆっくり動かす
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(0.2, 1.0)
	var ft := ForestArt.tex("far")
	far.repeat_size = Vector2(ft.get_width(), 0)
	far.repeat_times = 3
	far.z_index = -25
	var fsp := Sprite2D.new()
	fsp.texture = ft
	fsp.centered = false
	fsp.position = Vector2(0, GROUND + 40.0 - ft.get_height())
	far.add_child(fsp)
	add_child(far)

	# 中景：光の差す隙間・古いアーチ・茂み・枝。少しかすませる
	var mid := Parallax2D.new()
	mid.scroll_scale = Vector2(0.55, 1.0)
	mid.z_index = -20
	var mids := ["mid_light_gap", "mid_bush_02", "mid_old_arch", "mid_bush_01", "mid_light_gap", "mid_branch_01", "mid_bush_02"]
	for i in mids.size():
		var sp := Sprite2D.new()
		sp.texture = ForestArt.tex(mids[i])
		var sc := 0.62 if mids[i] != "mid_branch_01" else 0.8
		sp.scale = Vector2(sc, sc)
		sp.centered = false
		var h := sp.texture.get_height() * sc
		var y := 60.0 - h if mids[i] != "mid_branch_01" else -420.0
		sp.position = Vector2(-150.0 + i * 300.0, y)
		sp.flip_h = i % 2 == 1
		sp.modulate = Color(0.72, 0.8, 0.74)
		mid.add_child(sp)
	add_child(mid)


func _build_foreground() -> void:
	var fg := Parallax2D.new()
	fg.scroll_scale = Vector2(1.3, 1.1)
	fg.z_index = 50
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 6:
		var leaf := ForestArt.sprite("fg_leaf_01", Vector2.ZERO, 0.24)
		leaf.position = Vector2(200.0 + i * 760.0 + r.randf_range(-80, 80), 70.0)
		leaf.rotation = r.randf_range(-0.6, -0.2)
		leaf.flip_h = i % 2 == 0
		leaf.modulate = Color(0.32, 0.4, 0.28)
		fg.add_child(leaf)
	for i in 5:
		var vine := ForestArt.sprite("fg_vine_01", Vector2(560.0 + i * 900.0 + r.randf_range(-100, 100), -760.0), 0.42)
		vine.modulate = Color(0.4, 0.48, 0.36)
		fg.add_child(vine)
	add_child(fg)


func _entrance_sign() -> void:
	var board := Node2D.new()
	board.position = Vector2(ENTRANCE_X, GROUND)
	board.z_index = -1
	board.draw.connect(func() -> void:
		board.draw_rect(Rect2(-3, -48, 6, 48), Color(0.4, 0.28, 0.16))
		board.draw_colored_polygon(PackedVector2Array([Vector2(-34, -62), Vector2(26, -62), Vector2(26, -40), Vector2(-34, -40), Vector2(-44, -51)]), Color(0.62, 0.46, 0.28)))
	var l := Label.new()
	l.text = "村へ"
	l.theme = Game.ui_theme
	l.add_theme_font_size_override("font_size", 14)
	l.position = Vector2(-26, -63)
	board.add_child(l)
	world.add_child(board)


# ---- 遊び ----

## 攻撃が地形に当たった（Player から呼ばれる）。枝なら揺らして熟した実を落とす
func hit_tile(world_pos: Vector2, _power: int) -> bool:
	for b in branches:
		if world_pos.x >= b["x0"] - 8.0 and world_pos.x <= b["x1"] + 8.0 and world_pos.y >= b["top"] - 6.0 and world_pos.y <= b["top"] + 40.0:
			shake_branch(b)
			return true
	return false


func shake_branch(b: Dictionary) -> void:
	var sp: Sprite2D = b["sprite"]
	var y0 := sp.position.y
	var tw := create_tween()
	for i in 3:
		tw.tween_property(sp, "position:y", y0 + 4.0, 0.05)
		tw.tween_property(sp, "position:y", y0 - 2.0, 0.05)
	tw.tween_property(sp, "position:y", y0, 0.05)
	var n := 0
	for berry in b["berries"]:
		if not is_instance_valid(berry) or not berry.hanging:
			continue
		if berry.ripe():
			berry.drop(0.08 + n * 0.12)
			n += 1
		else:
			berry._wiggle = 0.4
	if n == 0 and b["berries"].any(func(x: Berry) -> bool: return is_instance_valid(x) and x.hanging):
		note_unripe()


func note_unripe() -> void:
	if unripe_noted:
		return
	unripe_noted = true
	Game.post("まだ青い実は、叩いても落ちない。")


func _physics_process(delta: float) -> void:
	# 籠の中で止まった実を収穫にする
	for bk in baskets:
		var area: Area2D = bk["area"]
		for body in area.get_overlapping_bodies():
			var berry := body as Berry
			if berry == null or berry.in_basket or berry.hanging:
				continue
			if berry.linear_velocity.length() < 45.0:
				berry.settle += delta
				if berry.settle >= 0.35:
					_collect(berry, bk)
			else:
				berry.settle = 0.0


func _collect(berry: Berry, bk: Dictionary) -> void:
	berry.put_in_basket()
	bk["count"] = int(bk["count"]) + 1
	if berry.item() != "":
		Game.add_item(berry.item(), 1)
		Game.post("籠に入れた：%s（この籠に %d 個）" % [Game.ITEM_NAMES[berry.item()], bk["count"]])


func on_interact() -> void:
	if absf(player.global_position.x - ENTRANCE_X) < 70.0:
		player.controls_locked = true
		Game.finish_run()


func on_player_down() -> void:
	player.heal_full()
	player.controls_locked = false
