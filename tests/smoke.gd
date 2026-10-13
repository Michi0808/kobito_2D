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
	check(used.size() > 1500, "地形が生成された（%d マス）" % used.size())
	var creatures := get_tree().get_nodes_in_group("creatures")
	check(creatures.size() >= 4, "生き物がいる（%d 匹）" % creatures.size())
	check(Game.boss != null, "坑道の主がいる")

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

	print("SMOKE FAILED" if failed else "SMOKE OK")
	get_tree().quit(1 if failed else 0)
