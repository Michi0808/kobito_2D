extends Node
## 画面写真を撮る（見た目の確認用）。 godot --path . -- --shots <出力フォルダ>

var out := ""


func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_state()
	var args := OS.get_cmdline_user_args()
	out = args[args.find("--shots") + 1]
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(3)
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	await frames(40)
	await shot("00_village_market")
	Game.player.global_position = Vector2(1300, 16 * 32 - 30)
	await frames(60)
	await shot("00b_village_shops")
	var b: BuildSystem = Game.level.build
	Game.add_item("bark", 40, false)
	Game.add_item("stone", 10, false)
	Game.add_item("shell", 10, false)
	Game.add_item("silk", 5, false)
	Game.add_item("amber", 5, false)
	for x in range(76, 85):
		b.place("back", Vector2i(x, 14))
		b.place("back", Vector2i(x, 15))
		b.place("roof", Vector2i(x, 13))
	b.place("wall", Vector2i(75, 14))
	b.place("door", Vector2i(75, 15))
	b.place("wall", Vector2i(85, 14))
	b.place("wall", Vector2i(85, 15))
	b.place("bench", Vector2i(80, 15))
	b.place("lamp", Vector2i(78, 14))
	Game.player.global_position = Vector2(80 * 32, 16 * 32 - 30)
	await frames(40)
	await shot("01_village")
	b.toggle()
	await shot("02_build_mode")
	b.toggle()
	Game.level.on_interact()
	await shot("03_workshop")
	Game.level.hud.close_craft()

	Game.goto_mine()
	await frames(30)
	await shot("04_mine_entrance")
	var m: Node = Game.level
	var p: Player = Game.player
	# 2段目あたりへ（ランタンなし）
	p.global_position = _air_near(m, 2)
	await frames(40)
	await shot("05_mine_dark_no_lantern")
	Game.has_lantern = true
	p.update_light()
	await frames(5)
	await shot("06_mine_dark_lantern")
	if Game.boss != null:
		p.global_position = Game.boss.global_position + Vector2(-140, -10)
		await frames(40)
		await shot("07_boss")

	Game.goto_forest()
	await frames(30)
	await shot("08_forest_entrance")
	var f: Node = Game.level
	Game.player.global_position = Vector2(1000, -30)
	f.shake_branch(f.branches[2])
	await frames(150)
	Game.player.global_position = Vector2(1250, -30)
	await frames(40)
	await shot("09_forest_basket")
	get_tree().quit()


func _air_near(m: Node, room_row: int) -> Vector2:
	var y0 := 1 + room_row * 12 + 8
	for x in range(2, m.map_w - 2):
		var c := Vector2i(x, y0)
		if m.tile_at(c) == -1 and m.tile_at(c + Vector2i.DOWN) >= 0:
			return Vector2(c) * 32 + Vector2(16, 18)
	return Game.player.global_position
