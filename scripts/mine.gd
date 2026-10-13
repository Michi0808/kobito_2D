extends Node2D
## 浅い坑道。入るたびに部屋テンプレートをつないで新しく生成する
## （設定書：鉱脈は季節と根の成長で少しずつ入れ替わる）。
## 下へ行くほど暗くなり、ランタンがないと奥はほとんど見えない。
##
## 絵は層に分けて重ねる（奥から）：遠景 → 中景 → 足場タイル → 鉱脈 → 飾り・はしご → 前景。
## 当たり判定は見えない map（32px の格子）が持ち、見た目は art/mine/ の手描き素材で別に描く。

const GW := 4  # 横に並ぶ部屋の数
const GH := 4  # 縦に並ぶ部屋の数
const T := Tiles.SIZE

var map: TileMapLayer  # 当たり判定と地形の種類（見えない）
var ground_view: TileMapLayer  # 足場タイルの見た目
var ore_view: TileMapLayer  # 鉱脈・岩・根の見た目（足場の上に重ねる）
var plat_view: TileMapLayer  # 葉っぱの足場・吊り橋の見た目
var props: Node2D  # はしご・飾り・灯り
var decor: Dictionary = {}  # Vector2i（支えているマス） -> Array[Node2D]
var ladders: Dictionary = {}  # Vector2i -> true
var view_ready := false
var cracks: Node2D
var damage: Dictionary = {}  # Vector2i -> 受けた打撃
var rng := RandomNumberGenerator.new()
var player: Player
var hud: HUD
var darkness: CanvasModulate
var map_w := 0
var map_h := 0
var exit_pos := Vector2.ZERO
var return_hold := 0.0
var root_msg_shown := false


func _ready() -> void:
	Game.level = self
	Game.boss = null
	rng.randomize()
	map_w = GW * MineRooms.W + 2
	map_h = GH * MineRooms.H + 2

	var back := Node2D.new()
	back.z_index = -20
	back.draw.connect(_draw_back.bind(back))
	add_child(back)

	map = TileMapLayer.new()
	map.tile_set = Tiles.get_tileset()
	map.visible = false
	add_child(map)

	var art := MineArt.get_tileset()
	for i in 3:
		var v := TileMapLayer.new()
		v.tile_set = art
		v.scale = Vector2(MineArt.SCALE, MineArt.SCALE)
		add_child(v)
		match i:
			0: ground_view = v
			1: ore_view = v
			2: plat_view = v

	props = Node2D.new()
	add_child(props)

	cracks = Node2D.new()
	cracks.draw.connect(_draw_cracks)
	add_child(cracks)

	darkness = CanvasModulate.new()
	add_child(darkness)

	var start_cell := generate()
	for x in map_w:
		for y in map_h:
			_paint_view(Vector2i(x, y))
	view_ready = true
	_decorate()
	_build_backdrop()

	player = Player.new()
	player.position = Vector2(start_cell) * T + Vector2(T / 2.0, T - Player.BODY.y / 2.0)
	add_child(player)
	player.set_camera_limits(Rect2(0, -T * 4, map_w * T, (map_h + 4) * T))

	if not Game.lost_bag.is_empty():
		var bag := Pickup.new().setup(Game.lost_bag.duplicate(), true)
		bag.position = player.position + Vector2(T * 3, 0)
		add_child(bag)

	hud = HUD.new()
	add_child(hud)
	hud.set_hint("歩く A/D　走る K長押し　ジャンプ Space（落ちながら長押しで滑空）　攻撃・掘る J（W/Sで上下）　ダッシュ K　村へ帰る E長押し")
	if not Game.has_lantern:
		Game.post("坑道に入った。下＋攻撃で足元を掘れる。奥は暗いので、ランタンがあると心強い。")
	else:
		Game.post("坑道に入った。ランタンが奥まで照らしている。")


# ---- 生成 ----

## 地図を作り、入口に立つマスを返す
func generate() -> Vector2i:
	# 1. 入口の部屋（一番上の段）から、横に歩いたり下に降りたりして一番下の段まで道を引く
	var cx := rng.randi_range(0, GW - 1)
	var cy := 0
	var start_room := Vector2i(cx, 0)
	var path := {start_room: true}
	var links: Array = []
	var dir := 1 if rng.randf() < 0.5 else -1
	var end_room := start_room
	while true:
		var cur := Vector2i(cx, cy)
		var go_down := rng.randf() < 0.3
		if not go_down:
			var nx := cx + dir
			if nx < 0 or nx >= GW:
				go_down = true
				dir = -dir
			else:
				links.append([cur, Vector2i(nx, cy)])
				cx = nx
				path[Vector2i(cx, cy)] = true
				continue
		if cy == GH - 1:
			end_room = cur
			break
		links.append([cur, Vector2i(cx, cy + 1)])
		cy += 1
		path[Vector2i(cx, cy)] = true
		dir = 1 if rng.randf() < 0.5 else -1

	# 2. 部屋ごとにテンプレートを流し込む
	var start_cell := Vector2i.ZERO
	var spawns: Array = []
	for ry in GH:
		for rx in GW:
			var room := Vector2i(rx, ry)
			var tpl: Array
			if room == start_room:
				tpl = MineRooms.START
			elif room == end_room:
				tpl = MineRooms.BOSS
			else:
				tpl = MineRooms.FILLERS[rng.randi_range(0, MineRooms.FILLERS.size() - 1)]
			var flip := rng.randf() < 0.5 and room != start_room
			for y in MineRooms.H:
				var row: String = tpl[y]
				for x in MineRooms.W:
					var ch := row[MineRooms.W - 1 - x] if flip else row[x]
					var cell := Vector2i(1 + rx * MineRooms.W + x, 1 + ry * MineRooms.H + y)
					match ch:
						"#": put_tile(cell, Tiles.DIRT)
						"R": put_tile(cell, Tiles.ROCK)
						"B": put_tile(cell, Tiles.BARK)
						"L": put_tile(cell, Tiles.LIVING_ROOT)
						"=": put_tile(cell, Tiles.LEAF)
						"~": put_tile(cell, Tiles.PLANK)
						"H":
							ladders[cell] = true
						"P":
							start_cell = cell
						"D":
							exit_pos = Vector2(cell) * T + Vector2(T / 2.0, T / 2.0)
						"a", "s", "X":
							spawns.append([ch, cell, ry])
			if room != start_room and room != end_room:
				_scatter_veins(room)

	# 3. 道の上の部屋どうしを穴でつなぐ
	for l in links:
		_carve_link(l[0], l[1])

	# 4. 外周は掘れない岩盤
	for x in map_w:
		put_tile(Vector2i(x, 0), Tiles.BEDROCK)
		put_tile(Vector2i(x, map_h - 1), Tiles.BEDROCK)
	for y in map_h:
		put_tile(Vector2i(0, y), Tiles.BEDROCK)
		put_tile(Vector2i(map_w - 1, y), Tiles.BEDROCK)

	# 5. 生き物を置く
	for s in spawns:
		_spawn_creature(s[0], s[1], s[2])
	return start_cell


func put_tile(cell: Vector2i, id: int) -> void:
	if id < 0:
		map.erase_cell(cell)
	else:
		map.set_cell(cell, 0, Vector2i(id, 0))
	if view_ready:
		for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_paint_view(cell + d)
		# 掘ったマスに乗っていた苔や灯りも一緒に消える
		for n in decor.get(cell, []):
			if is_instance_valid(n):
				n.queue_free()
		decor.erase(cell)


func tile_at(cell: Vector2i) -> int:
	if map.get_cell_source_id(cell) == -1:
		return -1
	return map.get_cell_atlas_coords(cell).x


## 土の中に鉱脈（琥珀鉱）、硬い岩、枯れた根の外皮を散らす。深いほど琥珀鉱が多い。
func _scatter_veins(room: Vector2i) -> void:
	var origin := Vector2i(1 + room.x * MineRooms.W, 1 + room.y * MineRooms.H)
	var veins := [[Tiles.AMBER, 2 + room.y, 3, 6], [Tiles.ROCK, 2, 4, 8], [Tiles.BARK, 1, 3, 5]]
	for v in veins:
		for n in int(v[1]):
			var c := origin + Vector2i(rng.randi_range(1, MineRooms.W - 2), rng.randi_range(1, MineRooms.H - 2))
			for step in rng.randi_range(int(v[2]), int(v[3])):
				if tile_at(c) == Tiles.DIRT:
					put_tile(c, int(v[0]))
				c += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]
				c.x = clampi(c.x, origin.x + 1, origin.x + MineRooms.W - 2)
				c.y = clampi(c.y, origin.y + 1, origin.y + MineRooms.H - 2)


func _carve_link(a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	if a.y == b.y:
		# 左右：境目の 6〜9 行目を通す
		var bx := 1 + (lo.x + 1) * MineRooms.W
		for x in range(bx - 4, bx + 4):
			for y in range(6, 10):
				_clear_breakable(Vector2i(x, 1 + lo.y * MineRooms.H + y))
	else:
		# 上下：8〜11 列目に縦穴。はしごをかけて登り返せるようにする
		var by := 1 + (lo.y + 1) * MineRooms.H
		var x0 := 1 + lo.x * MineRooms.W
		for y in range(by - 3, by + 4):
			for x in range(8, 12):
				_clear_breakable(Vector2i(x0 + x, y))
		# はしごは上の部屋の床より1マス上から、下の部屋の床に届くまで
		for y in range(by - 4, by + 4):
			if tile_at(Vector2i(x0 + 9, y)) < 0:
				ladders[Vector2i(x0 + 9, y)] = true
		var y := by + 4
		while y < by + 12 and tile_at(Vector2i(x0 + 9, y)) < 0:
			ladders[Vector2i(x0 + 9, y)] = true
			y += 1


func _clear_breakable(cell: Vector2i) -> void:
	var id := tile_at(cell)
	if id != Tiles.LIVING_ROOT:
		put_tile(cell, -1)


func _spawn_creature(kind: String, cell: Vector2i, depth: int) -> void:
	var c: Creature
	match kind:
		"a":
			c = Ant.new()
		"s":
			c = Spider.new()
		"X":
			if Game.boss_defeated:
				# 主を倒した後は、主の部屋に琥珀鉱の結晶が育っている
				for i in 4:
					put_tile(cell + Vector2i(i - 2, 3), Tiles.AMBER)
				return
			c = Beetle.new()
	if c == null:
		return
	c.position = Vector2(cell) * T + Vector2(T / 2.0, T / 2.0)
	if depth >= 2 and kind != "X":
		c.hp += 1
	add_child(c)


# ---- 掘る ----

## プレイヤーの攻撃が地形に当たった。固いものに当たったら true。
func hit_tile(world_pos: Vector2, power: int) -> bool:
	var cell := map.local_to_map(map.to_local(world_pos))
	var id := tile_at(cell)
	if id < 0 or Tiles.is_platform(id):
		return false
	if not Tiles.is_breakable(id):
		if id == Tiles.LIVING_ROOT and not root_msg_shown:
			root_msg_shown = true
			Game.post("生きた太い根は掘らない。木と坑道を傷めるから。")
		return true
	var d: int = int(damage.get(cell, 0)) + power
	if d >= int(Tiles.HARDNESS[id]):
		damage.erase(cell)
		put_tile(cell, -1)
		if Tiles.DROPS.has(id):
			spawn_pickup(map.map_to_local(cell), {Tiles.DROPS[id]: 1})
	else:
		damage[cell] = d
	cracks.queue_redraw()
	return true


func spawn_pickup(pos: Vector2, items: Dictionary) -> void:
	var p := Pickup.new().setup(items)
	p.position = pos
	call_deferred("add_child", p)


# ---- 帰る・倒れる ----

func on_interact() -> void:
	if player.global_position.distance_to(exit_pos) < 48.0:
		Game.finish_run()


func on_player_down() -> void:
	Game.player_fell()


func _physics_process(delta: float) -> void:
	if player == null or player.hp <= 0:
		return
	# 深さで暗さを変える。一番上はほのかに明るく、下の段はほぼ真っ暗
	var depth := clampf(player.global_position.y / (map_h * T), 0.0, 1.0)
	var v := lerpf(0.6, 0.05, depth)
	darkness.color = Color(v, v * 0.95, v * 0.9)

	# E 長押しで帰還（出口の近くなら一回押すだけ）
	if Input.is_action_pressed("interact") and player.global_position.distance_to(exit_pos) >= 48.0:
		return_hold += delta
		if return_hold >= 1.2:
			return_hold = 0.0
			player.controls_locked = true
			Game.finish_run()
	else:
		return_hold = 0.0


# ---- 見た目（層ごと） ----

## はしごの上にいるか（Player が使う）
func is_ladder(world_pos: Vector2) -> bool:
	return ladders.has(map.local_to_map(map.to_local(world_pos)))


## 見た目で「続いている」とみなすマス。地図の外は岩盤が続いている扱い
func _solid_for_view(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return true
	var id := tile_at(cell)
	return id >= 0 and not Tiles.is_platform(id)


## 1マスぶんの見た目を、まわりのマスとのつながりから選び直す
func _paint_view(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return
	var id := tile_at(cell)
	var h := absi(hash(cell))
	if id < 0 or Tiles.is_platform(id):
		ground_view.erase_cell(cell)
		ore_view.erase_cell(cell)
		if id < 0:
			plat_view.erase_cell(cell)
		else:
			# 左端・まん中・右端
			var piece := 1
			if tile_at(cell + Vector2i.LEFT) != id:
				piece = 0
			elif tile_at(cell + Vector2i.RIGHT) != id:
				piece = 2
			plat_view.set_cell(cell, MineArt.SRC_PLATFORM[id], Vector2i(piece, 0))
		return
	plat_view.erase_cell(cell)
	var mask := 0
	if _solid_for_view(cell + Vector2i.UP):
		mask |= 1
	if _solid_for_view(cell + Vector2i.RIGHT):
		mask |= 2
	if _solid_for_view(cell + Vector2i.DOWN):
		mask |= 4
	if _solid_for_view(cell + Vector2i.LEFT):
		mask |= 8
	var vx := posmod(cell.x, MineArt.VARIANTS)
	var vy := posmod(cell.y, MineArt.VARIANTS)
	if mask == 15:
		ground_view.set_cell(cell, MineArt.SRC_FILL, Vector2i(vx, vy))
	else:
		# 上下とも続く（縦の壁面）なら縦方向、それ以外は横方向に柄を送ると、縁の帯が途切れない
		ground_view.set_cell(cell, MineArt.SRC_TERRAIN, Vector2i(vy if mask & 5 == 5 else vx, mask))
	if MineArt.SRC_ORE.has(id):
		ore_view.set_cell(cell, MineArt.SRC_ORE[id], Vector2i(h % 2, 0))
	else:
		ore_view.erase_cell(cell)


func _add_decor(cell: Vector2i, n: Node2D) -> void:
	props.add_child(n)
	if not decor.has(cell):
		decor[cell] = []
	decor[cell].append(n)


## はしご・吊り橋の柱・苔・小石・結晶・ランタン・垂れた根を置く
func _decorate() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	for cell in ladders:
		var lad := MineArt.sprite("ladder", map.map_to_local(cell) + Vector2(0, T / 2.0))
		lad.z_index = -1
		props.add_child(lad)
	var lanterns_in_room := {}
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			var cell := Vector2i(x, y)
			var id := tile_at(cell)
			var center := map.map_to_local(cell)
			var top := center + Vector2(0, -T / 2.0)
			var bottom := center + Vector2(0, T / 2.0)
			if id == Tiles.PLANK:
				# 吊り橋の両端に柱
				if tile_at(cell + Vector2i.LEFT) != Tiles.PLANK:
					props.add_child(MineArt.sprite("bridge_post", top + Vector2(-T / 2.0, T / 2.0)))
				if tile_at(cell + Vector2i.RIGHT) != Tiles.PLANK:
					var p := MineArt.sprite("bridge_post", top + Vector2(T / 2.0, T / 2.0))
					p.flip_h = true
					props.add_child(p)
				continue
			if id < 0 or Tiles.is_platform(id) or id == Tiles.BEDROCK:
				continue
			var air_above := tile_at(cell + Vector2i.UP) < 0 and not ladders.has(cell + Vector2i.UP)
			var air_below := tile_at(cell + Vector2i.DOWN) < 0
			if air_above:
				var room := Vector2i((x - 1) / MineRooms.W, (y - 1) / MineRooms.H)
				var roll := r.randf()
				var tall := tile_at(cell + Vector2i(0, -2)) < 0 and tile_at(cell + Vector2i(0, -3)) < 0
				if id == Tiles.AMBER and roll < 0.6:
					var cr := MineArt.sprite("deco_crystal", top + Vector2(0, 4), false, r)
					cr.add_child(MineArt.light(Color(1.0, 0.65, 0.25), 1.6, 0.7))
					_add_decor(cell, cr)
				elif tall and roll < 0.05 and int(lanterns_in_room.get(room, 0)) < 2:
					lanterns_in_room[room] = int(lanterns_in_room.get(room, 0)) + 1
					var la := MineArt.sprite("deco_lantern", top + Vector2(0, 2), false, r)
					var l := MineArt.light(Color(1.0, 0.72, 0.38), 3.2, 1.0)
					# 灯りは絵の中のランタンの位置に（どちらの絵か見て決める）
					l.position = Vector2(13, -17) if la.texture.resource_path.ends_with("_v2.png") else Vector2(-14, -3)
					la.add_child(l)
					la.flip_h = r.randf() < 0.5
					if la.flip_h:
						l.position.x = -l.position.x
					_add_decor(cell, la)
				elif roll < 0.4:
					_add_decor(cell, MineArt.sprite("deco_moss", top + Vector2(0, 5), false, r))
				elif roll < 0.5:
					_add_decor(cell, MineArt.sprite("deco_pebbles", top + Vector2(0, 2), false, r))
				elif roll < 0.53 and tall:
					_add_decor(cell, MineArt.sprite("deco_basket", top + Vector2(0, 2), false, r))
			if air_below and r.randf() < 0.18:
				var rt := MineArt.sprite("deco_roots_hang", bottom - Vector2(0, 4), true, r)
				rt.z_index = -1
				_add_decor(cell, rt)


## 遠景・中景・前景
func _build_backdrop() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	var world := Vector2(map_w * T, map_h * T)

	# 遠景：横につながる絵を、ゆっくり動かす
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(0.25, 0.25)
	var ft := MineArt.tex("far")
	var fs := 1080.0 / ft.get_height()  # 遠景は 1920×1080 で描く
	far.repeat_size = Vector2(ft.get_width() * fs, 0)
	far.repeat_times = 3
	far.z_index = -15
	var fsp := Sprite2D.new()
	fsp.texture = ft
	fsp.centered = false
	fsp.scale = Vector2(fs, fs)
	fsp.position = Vector2(0, -T * 4)
	far.add_child(fsp)
	add_child(far)

	# 中景：大きな岩壁と根を、足場の後ろに暗めに散らす
	var mid := Parallax2D.new()
	mid.scroll_scale = Vector2(0.8, 0.8)
	mid.z_index = -10
	var mids := ["mid_rock_wall", "mid_root_arch", "mid_tunnel", "mid_rock_wall", "mid_root_arch", "mid_pulley", "mid_workshop"]
	for i in GW * GH * 2:
		var sp := Sprite2D.new()
		sp.texture = MineArt.tex(mids[r.randi_range(0, mids.size() - 1)])
		sp.position = Vector2(r.randf_range(0, world.x), r.randf_range(0, world.y)) * 0.85
		sp.scale = Vector2.ONE * r.randf_range(0.35, 0.5)
		sp.flip_h = r.randf() < 0.5
		sp.modulate = Color(0.27, 0.28, 0.36)
		mid.add_child(sp)
	add_child(mid)

	# 前景：手前を通る太い根。速めに動き、ほぼ影になる
	var fg := Parallax2D.new()
	fg.scroll_scale = Vector2(1.25, 1.25)
	fg.z_index = 50
	for i in GW * GH / 2:
		var sp := Sprite2D.new()
		sp.texture = MineArt.tex("fg_roots" if r.randf() < 0.5 else "fg_vines")
		sp.position = Vector2(r.randf_range(0, world.x), r.randf_range(0, world.y)) * 1.25
		sp.scale = Vector2.ONE * r.randf_range(0.7, 1.0)
		sp.flip_h = r.randf() < 0.5
		sp.modulate = Color(0.12, 0.1, 0.09)
		fg.add_child(sp)
	add_child(fg)


func _draw_back(node: Node2D) -> void:
	node.draw_rect(Rect2(-T * 20, -T * 20, (map_w + 40) * T, (map_h + 40) * T), Color(0.06, 0.06, 0.08))


func _draw_cracks() -> void:
	for cell in damage:
		var id := tile_at(cell)
		if id < 0:
			continue
		var ratio := float(damage[cell]) / float(Tiles.HARDNESS[id])
		var o := Vector2(cell) * T
		var c := Color(0.05, 0.03, 0.02, 0.85)
		cracks.draw_line(o + Vector2(16, 4), o + Vector2(12, 16), c, 2.0)
		cracks.draw_line(o + Vector2(12, 16), o + Vector2(20, 26), c, 2.0)
		if ratio > 0.5:
			cracks.draw_line(o + Vector2(12, 16), o + Vector2(4, 20), c, 2.0)
			cracks.draw_line(o + Vector2(20, 10), o + Vector2(28, 8), c, 2.0)


func _draw() -> void:
	# 村への出口（縄ばしごの掛かった穴）
	var o := exit_pos
	draw_rect(Rect2(o + Vector2(-14, -40), Vector2(28, 56)), Color(0.08, 0.06, 0.05))
	draw_line(o + Vector2(-6, -40), o + Vector2(-6, 16), Color(0.7, 0.55, 0.3), 2.0)
	draw_line(o + Vector2(6, -40), o + Vector2(6, 16), Color(0.7, 0.55, 0.3), 2.0)
	for i in 6:
		draw_line(o + Vector2(-6, -36 + i * 9), o + Vector2(6, -36 + i * 9), Color(0.7, 0.55, 0.3), 2.0)
	draw_circle(o + Vector2(-20, -30), 4.0, Color(1.0, 0.72, 0.3))
