class_name HUD
extends CanvasLayer
## 画面の表示：体力、持ち物、メッセージ、操作説明、主の体力、帰還ゲージ、建築と工房の画面。

var root: Control
var hearts: Control
var inv_label: Label
var msg_label: Label
var hint_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var return_bar: ProgressBar
var build_label: Label
var craft_panel: PanelContainer
var craft_list: VBoxContainer
var msg_time := 0.0
var craft_closed_at := 0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Game.ui_theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hearts = Control.new()
	hearts.position = Vector2(20, 16)
	hearts.size = Vector2(220, 28)
	hearts.draw.connect(_draw_hearts)
	root.add_child(hearts)

	inv_label = _label(Vector2(20, 50), 17)

	msg_label = _label(Vector2(140, 560), 20)
	msg_label.size = Vector2(1000, 60)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hint_label = _label(Vector2(20, 684), 14)
	hint_label.modulate = Color(1, 1, 1, 0.8)

	boss_box = VBoxContainer.new()
	boss_box.position = Vector2(390, 18)
	boss_box.size = Vector2(500, 40)
	root.add_child(boss_box)
	var bl := Label.new()
	bl.text = "坑道の主・大甲虫"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(bl)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(500, 12)
	boss_bar.show_percentage = false
	boss_box.add_child(boss_bar)
	boss_box.visible = false

	return_bar = ProgressBar.new()
	return_bar.position = Vector2(540, 520)
	return_bar.size = Vector2(200, 12)
	return_bar.show_percentage = false
	return_bar.max_value = 1.2
	return_bar.visible = false
	root.add_child(return_bar)

	build_label = _label(Vector2(900, 50), 16)
	build_label.visible = false

	_build_craft_panel()

	Game.inventory_changed.connect(_refresh_inv)
	Game.message_posted.connect(show_message)
	_refresh_inv()
	if Game.queued_message != "":
		show_message(Game.queued_message)
		Game.queued_message = ""


func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func set_hint(text: String) -> void:
	hint_label.text = text


func show_message(text: String) -> void:
	msg_label.text = text
	msg_time = 4.5


func _refresh_inv() -> void:
	var lines: PackedStringArray = []
	for id in Game.ITEM_ORDER:
		lines.append("%s　%d" % [Game.ITEM_NAMES[id], int(Game.inv.get(id, 0))])
	var tools := "つるはし Lv%d" % Game.pick_level
	if Game.has_lantern:
		tools += "・ランタン"
	lines.append(tools)
	inv_label.text = "\n".join(lines)


func _process(delta: float) -> void:
	hearts.queue_redraw()
	msg_time -= delta
	msg_label.modulate.a = clampf(msg_time, 0.0, 1.0)

	var b := Game.boss as Beetle
	var p := Game.player as Player
	boss_box.visible = b != null and is_instance_valid(b) and p != null and b.global_position.distance_to(p.global_position) < 520.0
	if boss_box.visible:
		boss_bar.max_value = b.max_hp
		boss_bar.value = b.hp

	var hold := 0.0
	if Game.level != null and "return_hold" in Game.level:
		hold = Game.level.return_hold
	return_bar.visible = hold > 0.05
	return_bar.value = hold


func _draw_hearts() -> void:
	var p := Game.player as Player
	var hp := p.hp if p != null and is_instance_valid(p) else 0
	for i in Game.max_hp:
		var c := Vector2(12 + i * 30, 12)
		hearts.draw_circle(c, 11.0, Color(0.1, 0.07, 0.05, 0.8))
		if i < hp:
			hearts.draw_circle(c, 8.0, Color(1.0, 0.7, 0.25))
			hearts.draw_circle(c + Vector2(-2, -2), 2.5, Color(1, 0.95, 0.8))


# ---- 建築 ----

func show_build(text: String) -> void:
	build_label.visible = text != ""
	build_label.text = text


# ---- 工房 ----

func _build_craft_panel() -> void:
	craft_panel = PanelContainer.new()
	craft_panel.position = Vector2(390, 180)
	craft_panel.custom_minimum_size = Vector2(500, 0)
	craft_panel.visible = false
	root.add_child(craft_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	craft_panel.add_child(box)
	var title := Label.new()
	title.text = "工房（作業台）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	craft_list = VBoxContainer.new()
	box.add_child(craft_list)


func is_craft_open() -> bool:
	return craft_panel.visible


func open_craft() -> void:
	for c in craft_list.get_children():
		c.queue_free()
	var first: Button = null
	for r in Game.RECIPES:
		var btn := Button.new()
		var done := Game.recipe_done(r["id"])
		btn.text = "%s　（%s）\n%s%s" % [r["name"], Game.cost_text(r["cost"]), r["desc"], "　…作成済み" if done else ""]
		btn.disabled = done or not Game.can_afford(r["cost"])
		btn.pressed.connect(_on_craft.bind(r["id"]))
		craft_list.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
	var close := Button.new()
	close.text = "閉じる"
	close.pressed.connect(close_craft)
	craft_list.add_child(close)
	craft_panel.visible = true
	(first if first != null else close).call_deferred("grab_focus")
	if Game.player != null:
		Game.player.controls_locked = true


func close_craft() -> void:
	craft_panel.visible = false
	craft_closed_at = Time.get_ticks_msec()
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.call_deferred("set", "controls_locked", false)


func _on_craft(id: String) -> void:
	if Game.craft(id):
		var p := Game.player as Player
		if p != null:
			p.update_light()
	open_craft()


func _unhandled_input(event: InputEvent) -> void:
	if craft_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close_craft()
		get_viewport().set_input_as_handled()
