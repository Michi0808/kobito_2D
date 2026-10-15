extends Node
## 通しの動作確認。 godot --headless --path . -- --smoke で実行する。
## 村で小屋と工房を建てる → ランタンを作る → 坑道を生成して掘る・戦う → 倒れて村へ戻る、を自動で確かめる。

var failed := false


func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_state()
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failed = true
		push_error("FAIL " + what)
		print("  NG  ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await frames(5)
	print("== 村")
	var v: Node = Game.level
	check(v != null and v.name == "Village", "村が読み込まれた")
	var b: BuildSystem = v.build

	# 工房：床の上ではなく地面(16行目)の上 15 行目に作業台、左右に壁、上に屋根
	Game.add_item("bark", 30, false)
	Game.add_item("stone", 10, false)
	Game.add_item("shell", 10, false)
	Game.add_item("silk", 5, false)
	check(b.place("bench", Vector2i(80, 15)), "作業台を置けた")
	check(not b.is_workshop(Vector2i(80, 15)), "囲う前は工房として働かない")
	for y in [14, 15]:
		check(b.place("wall", Vector2i(77, y)), "左の壁 y=%d" % y)
		check(b.place("wall", Vector2i(83, y)), "右の壁 y=%d" % y)
	for x in range(77, 84):
		b.place("roof", Vector2i(x, 13))
	check(b.is_workshop(Vector2i(80, 15)), "屋根と壁で囲うと工房になる")
	check(not b.place("wall", Vector2i(10, 15)), "建築範囲の外には置けない")
	check(b.remove_at(Vector2i(83, 14)), "部品を外せる")
	check(b.place("wall", Vector2i(83, 14)), "外した場所にまた置ける")

	Game.add_item("amber", 3, false)
	check(Game.craft("lantern"), "ランタンを作れた")
	check(Game.has_lantern, "ランタンを持っている")

	# 歩いてみる
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	Input.action_press("jump")
	await frames(20)
	Input.action_release("jump")
	await frames(30)
	check((Game.player as Player).is_on_floor(), "ジャンプして地面に戻った")

	print("== 坑道")
	Game.goto_mine()
	await frames(10)
	var m: Node = Game.level
	check(m != null and m.name == "Mine", "坑道が読み込まれた")
	var used: Array = m.map.get_used_cells()
	check(used.size() > 900, "地形が生成された（%d マス）" % used.size())
	var creatures := get_tree().get_nodes_in_group("creatures")
	check(creatures.size() >= 4, "生き物がいる（%d 匹）" % creatures.size())
	check(Game.boss != null, "坑道の主がいる")

	check(m.ground_view.get_used_cells().size() == used.size() - m.plat_view.get_used_cells().size(), "足場の見た目が当たり判定と同じマスに描かれた")
	check(m.ladders.size() > 0, "はしごがある（%d マス）" % m.ladders.size())

	# はしごを登る
	var p0 := Game.player as Player
	var start_pos := p0.global_position
	var lad: Vector2i = m.ladders.keys()[0]
	for c in m.ladders:
		if m.ladders.has(c + Vector2i(0, -3)):
			lad = c
			break
	p0.global_position = m.map.map_to_local(lad)
	p0.velocity = Vector2.ZERO
	var y_before := p0.global_position.y
	Input.action_press("up")
	await frames(12)
	check(p0.climbing, "はしごにつかまった")
	check(p0.global_position.y < y_before - 10.0, "はしごを登った")
	Input.action_release("up")
	await frames(10)
	check(p0.climbing and absf(p0.velocity.y) < 1.0, "はしごの途中で止まれる")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(not p0.climbing, "ジャンプではしごを離れる")
	p0.global_position = start_pos
	p0.velocity = Vector2.ZERO
	await frames(10)

	# 掘ると見た目も消え、まわりの縁が描き直される
	var dug_view := Vector2i(-1, -1)
	for c in used:
		if m.tile_at(c) == Tiles.DIRT and m.tile_at(c + Vector2i.UP) == Tiles.DIRT and c.y > 2 and c.y < m.map_h - 3 and c.x > 2 and c.x < m.map_w - 3:
			dug_view = c
			break
	m.hit_tile(m.map.map_to_local(dug_view), 1)
	check(m.ground_view.get_cell_source_id(dug_view) == -1, "掘ったマスの見た目が消えた")
	var up_coords: Vector2i = m.ground_view.get_cell_atlas_coords(dug_view + Vector2i.UP)
	check(m.ground_view.get_cell_source_id(dug_view + Vector2i.UP) == MineArt.SRC_TERRAIN and (up_coords.x + up_coords.y * 4) & 4 == 0, "上のマスが「下が開いた」形に描き直された")

	# 足元を掘る
	var p := Game.player as Player
	var below: Vector2i = m.map.local_to_map(p.global_position) + Vector2i(0, 1)
	var before: int = m.tile_at(below)
	check(before == Tiles.DIRT, "入口の足元は土")
	m.hit_tile(m.map.map_to_local(below), 1)
	check(m.tile_at(below) == -1, "土は一回で掘れる")

	# 琥珀鉱を掘って拾う
	var ore := Vector2i(-1, -1)
	for c in used:
		if m.tile_at(c) == Tiles.AMBER:
			ore = c
			break
	check(ore.x >= 0, "琥珀鉱の鉱脈がある")
	var amber_before := int(Game.inv["amber"])
	for i in 3:
		m.hit_tile(m.map.map_to_local(ore), 1)
	check(m.tile_at(ore) == -1, "琥珀鉱は三回で掘れる")
	await frames(2)
	var drops := 0
	for n in m.get_children():
		if n is Pickup:
			drops += 1
	check(drops >= 1, "掘った琥珀鉱が落ちている")
	for n in m.get_children():
		if n is Pickup:
			n.global_position = p.global_position
	await frames(5)
	check(int(Game.inv["amber"]) > amber_before, "琥珀鉱を拾った")

	# 生き物を倒すと材料を落とす（鉱石は落とさない）
	var ant: Creature = null
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Ant:
			ant = c
			break
	if ant != null:
		ant.hurt(10, ant.global_position + Vector2(-10, 0))
		await frames(2)
		var shells := 0
		for n in m.get_children():
			if n is Pickup and n.items.has("shell"):
				shells += 1
			if n is Pickup:
				check(not n.items.has("amber") or n.global_position.distance_to(ant.global_position) > 1.0, "生き物は琥珀鉱を落とさない")
		check(shells >= 1, "アリは殻を落とす")

	# 攻撃ボタンで実際に掘る
	Input.action_press("down")
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	Input.action_release("down")
	await frames(30)

	# 倒れると村へ運ばれ、収穫の半分を落とす
	Game.run_gain = {"amber": 4}
	Game.inv["amber"] = int(Game.inv["amber"]) + 4
	p.invuln = 0.0
	p.take_damage(99, p.global_position + Vector2(10, 0))
	check(Game.lost_bag.get("amber", 0) == 2, "倒れると今回の収穫の半分を落とす")
	await get_tree().create_timer(1.3).timeout
	await frames(5)
	check(Game.level != null and Game.level.name == "Village", "村へ運ばれた")
	check(Game.level.build.is_workshop(Vector2i(80, 15)), "建てた工房が残っている")

	print("== 坑道（2回目）")
	Game.goto_mine()
	await frames(10)
	var bag := 0
	for n in Game.level.get_children():
		if n is Pickup and n.is_bag:
			bag += 1
	check(bag == 1, "落とし物の袋が入口近くにある")

	# 主の部屋まで少し走らせて、物理で落ちないことを確認
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check(Game.player.global_position.y < Game.level.map_h * Tiles.SIZE, "地形の外に落ちていない")

	await _forest()

	print("SMOKE FAILED" if failed else "SMOKE OK")
	get_tree().quit(1 if failed else 0)


func _forest() -> void:
	print("== 森")
	Game.finish_run()
	await frames(10)
	var v: Node = Game.level
	(Game.player as Player).global_position = Vector2(v.FOREST_PX, 16 * 32 - 30)
	v.on_interact()
	await frames(10)
	var f: Node = Game.level
	check(f != null and f.name == "Forest", "村の右端から森に入った")
	check(Game.bgm_path == Game.FOREST_BGM, "森の曲に替わった")
	var p := Game.player as Player
	await frames(20)
	check(p.is_on_floor(), "森の地面に立っている")
	var hanging := get_tree().get_nodes_in_group("berries").filter(func(b: Berry) -> bool: return b.hanging)
	check(hanging.size() >= 20, "枝に実がなっている（%d 個）" % hanging.size())

	# 籠の真上の枝の実を叩くと落ちて籠に入る
	var basket_x: float = f.baskets[0]["area"].get_child(0).global_position.x
	var target: Berry = null
	for b in hanging:
		if b.ripe() and absf(b.global_position.x - basket_x) < 40.0:
			target = b
			break
	check(target != null, "籠の上に熟した実がある")
	var before := int(Game.inv["berry_black"]) + int(Game.inv["berry_red"])
	check(target.on_hit(1, Vector2.UP, target.global_position + Vector2(0, 40)), "実を叩けた")
	await frames(150)
	check(target.in_basket, "落ちた実が籠に入った")
	check(int(Game.inv["berry_black"]) + int(Game.inv["berry_red"]) == before + 1, "籠に入った実が持ち物に加わった")

	# 熟していない実は落ちない
	var green: Berry = null
	for b in hanging:
		if not b.ripe():
			green = b
			break
	green.on_hit(1, Vector2.UP, green.global_position)
	await frames(30)
	check(green.hanging, "青い実は叩いても落ちない")

	# 枝の上で下攻撃すると、その枝の熟した実がまとめて落ちる
	var br: Dictionary = f.branches[0]
	p.global_position = Vector2((br["x0"] + br["x1"]) / 2.0, br["top"] - Player.BODY.y / 2.0 - 2.0)
	p.velocity = Vector2.ZERO
	await frames(15)
	check(p.is_on_floor() and absf(p.global_position.y - (br["top"] - Player.BODY.y / 2.0)) < 3.0, "枝の上に立てる")
	Input.action_press("down")
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	Input.action_release("down")
	await frames(80)
	var still := 0
	for b in br["berries"]:
		if b.ripe() and b.hanging:
			still += 1
	check(still == 0, "枝を揺らすと熟した実が全部落ちた")

	# 地面の実を体当たりで動かす
	var fallen: Berry = null
	for b in br["berries"]:
		if b.ripe() and not b.in_basket:
			fallen = b
			break
	await frames(60)
	p.global_position = fallen.global_position + Vector2(-70, -Player.BODY.y / 2.0 + fallen.radius)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(10)
	var x0 := fallen.global_position.x
	Input.action_press("move_right")
	await frames(70)
	Input.action_release("move_right")
	check(fallen.global_position.x > x0 + 30.0, "歩いて押すと実が転がる（%.0f px）" % (fallen.global_position.x - x0))
	# 体当たりは開けた所で試す
	fallen = Berry.new().setup("black_m", false)
	fallen.position = Vector2(1600, -15)
	f.world.add_child(fallen)
	await frames(30)
	x0 = fallen.global_position.x
	p.global_position = fallen.global_position + Vector2(-40, -Player.BODY.y / 2.0 + fallen.radius)
	p.facing = 1
	p.dash_cd = 0.0
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	await frames(30)
	check(fallen.global_position.x > x0 + 60.0, "体当たりで実が弾け飛ぶ（%.0f px）" % (fallen.global_position.x - x0))

	# 坂を押し上げて籠に入れる：籠Aの左の坂のふもとに実を置き、右へ押し続ける
	var ramp_berry := Berry.new().setup("black_m", false)
	ramp_berry.position = Vector2(1080, -15)
	f.world.add_child(ramp_berry)
	await frames(20)
	p.global_position = Vector2(1030, -Player.BODY.y / 2.0)
	p.velocity = Vector2.ZERO
	var inv_before := int(Game.inv["berry_black"])
	Input.action_press("move_right")
	await frames(170)
	Input.action_release("move_right")
	await frames(90)
	check(ramp_berry.in_basket, "葉の坂を押し上げて籠に入れた")
	check(int(Game.inv["berry_black"]) > inv_before, "坂から入れた実も持ち物に加わった")

	# 入口で E を押すと村へ戻り、森への道の前に立つ
	p.global_position = Vector2(f.ENTRANCE_X + 20.0, -Player.BODY.y / 2.0)
	await frames(5)
	f.on_interact()
	await frames(10)
	check(Game.level != null and Game.level.name == "Village", "森から村へ戻った")
	check(absf(Game.player.global_position.x - Game.level.FOREST_PX) < 80.0, "森への道の前に戻った")
	check(Game.bgm_path == Game.MAIN_BGM, "村の曲に戻った")
