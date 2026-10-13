class_name Npc
extends Node2D
## 村の住民（仮）。近づくとひとこと話す。

var npc_name := ""
var line := ""
var coat := Color(0.4, 0.4, 0.5)
var label: Label
var near := false


func setup(n: String, text: String, c: Color) -> Npc:
	npc_name = n
	line = text
	coat = c
	return self


func _ready() -> void:
	label = Label.new()
	label.theme = Game.ui_theme
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(-110, -118)
	label.size = Vector2(220, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = npc_name
	add_child(label)


func _process(_delta: float) -> void:
	var p := Game.player as Player
	var now := p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < 80.0
	if now != near:
		near = now
		label.text = "%s「%s」" % [npc_name, line] if near else npc_name


func _draw() -> void:
	# 仮の図形を主人公の大きさに合わせて2.5倍で描く
	draw_set_transform(Vector2(0, -19.5), 0.0, Vector2(2.5, 2.5))
	draw_rect(Rect2(-6, 9, 4, 4), Color(0.3, 0.2, 0.12))
	draw_rect(Rect2(2, 9, 4, 4), Color(0.3, 0.2, 0.12))
	draw_rect(Rect2(-8, -4, 16, 14), coat)
	draw_circle(Vector2(0, -10), 7.5, Color(0.93, 0.78, 0.64))
	draw_circle(Vector2(-3, -10), 1.3, Color(0.1, 0.07, 0.05))
