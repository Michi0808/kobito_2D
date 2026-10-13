extends Node
## 主人公のアニメの各コマを撮る（見た目の確認用）。 godot --path . -- --poses <出力フォルダ>

var out := ""


func _ready() -> void:
	Game.saving_enabled = false
	var args := OS.get_cmdline_user_args()
	out = args[args.find("--poses") + 1]
	_run.call_deferred()


func _run() -> void:
	for i in 20:
		await get_tree().process_frame
	var p: Player = Game.player
	p.set_physics_process(false)
	p.global_position = Vector2(1300, 16 * 32 - 27)
	p.camera.zoom = Vector2(6, 6)
	p.camera.position = Vector2(0, -10)
	p.camera.position_smoothing_enabled = false
	Game.level.hud.visible = false
	var v: PlayerVisual = p.visual
	v.set_process(false)
	var poses := [
		["idle", PlayerVisual.Move.IDLE, [0.0]],
		["walk", PlayerVisual.Move.WALK, [0.0, 0.08, 0.17, 0.26, 0.35, 0.44]],
		["run", PlayerVisual.Move.RUN, [0.0, 0.05, 0.1, 0.15, 0.2, 0.25]],
		["jump", PlayerVisual.Move.RISE, [0.0]],
		["fall", PlayerVisual.Move.FALL, [0.0]],
	]
	for pose in poses:
		v.move = pose[1]
		var i := 0
		for tt in pose[2]:
			v.t = tt
			for k in 20:
				v.t = tt
				v._process(0.05)
				v.t = tt
			await _shot("%s_%d" % [pose[0], i])
			i += 1
	v.move = PlayerVisual.Move.IDLE
	for kind in ["side", "down"]:
		for i in 6:
			v.swing_kind = kind
			v.swing_t = PlayerVisual.SWING_TIME * (1.0 - (0.1 + i * 0.17))
			v._process(0.0)
			await _shot("%s_%d" % [kind, i])
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.crop(1280, 720)
	img = img.get_region(Rect2i(440, 60, 400, 600))
	img.save_png(out.path_join(name + ".png"))
