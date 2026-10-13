class_name BuiltPart
extends Node2D
## 村に置いた建築部品ひとつ。絵は仮の図形（殻や樹皮らしい形）で、あとで手描きに差し替える。

const T := Tiles.SIZE

var kind := ""
## 作業台が工房として働いているか
var working := false


func _draw() -> void:
	draw_part(self, kind, Vector2.ZERO, 1.0, working)


static func draw_part(ci: CanvasItem, k: String, o: Vector2, a: float, on: bool) -> void:
	var wood := Color(0.55, 0.37, 0.22, a)
	var dark := Color(0.35, 0.23, 0.13, a)
	match k:
		"floor":
			ci.draw_rect(Rect2(o, Vector2(T, 8)), wood)
			ci.draw_line(o + Vector2(0, 8), o + Vector2(T, 8), dark, 2.0)
			ci.draw_line(o + Vector2(T / 2.0, 0), o + Vector2(T / 2.0, 8), dark, 1.0)
		"wall":
			ci.draw_rect(Rect2(o + Vector2(2, 0), Vector2(T - 4, T)), wood)
			for i in 3:
				ci.draw_line(o + Vector2(8 + i * 8, 2), o + Vector2(8 + i * 8, T - 2), dark, 1.5)
		"door":
			ci.draw_rect(Rect2(o + Vector2(4, 4), Vector2(T - 8, T - 4)), Color(0.25, 0.16, 0.09, a))
			ci.draw_arc(o + Vector2(T / 2.0, 10), 12.0, PI, TAU, 10, wood, 3.0)
			ci.draw_line(o + Vector2(4, 10), o + Vector2(4, T), wood, 3.0)
			ci.draw_line(o + Vector2(T - 4, 10), o + Vector2(T - 4, T), wood, 3.0)
		"roof":
			# 殻を重ねた屋根
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-2, 10), o + Vector2(T / 2.0, 0), o + Vector2(T + 2, 10), o + Vector2(T + 2, 14), o + Vector2(-2, 14)]), Color(0.78, 0.68, 0.48, a))
			ci.draw_line(o + Vector2(-2, 14), o + Vector2(T + 2, 14), Color(0.5, 0.42, 0.28, a), 2.0)
		"back":
			ci.draw_rect(Rect2(o, Vector2(T, T)), Color(0.3, 0.22, 0.15, a * 0.9))
			ci.draw_line(o + Vector2(0, T / 2.0), o + Vector2(T, T / 2.0), Color(0.24, 0.17, 0.11, a), 1.0)
		"bench":
			ci.draw_rect(Rect2(o + Vector2(2, 12), Vector2(T - 4, 6)), wood)
			ci.draw_rect(Rect2(o + Vector2(4, 18), Vector2(4, T - 18)), dark)
			ci.draw_rect(Rect2(o + Vector2(T - 8, 18), Vector2(4, T - 18)), dark)
			ci.draw_circle(o + Vector2(T / 2.0, 8), 4.0, Color(0.6, 0.6, 0.65, a))
			if on:
				ci.draw_circle(o + Vector2(T / 2.0, -6), 4.0, Color(1.0, 0.75, 0.3, a))
		"lamp":
			ci.draw_line(o + Vector2(T / 2.0, 0), o + Vector2(T / 2.0, 8), dark, 1.5)
			ci.draw_rect(Rect2(o + Vector2(10, 8), Vector2(12, 14)), Color(0.3, 0.22, 0.14, a))
			ci.draw_rect(Rect2(o + Vector2(12, 10), Vector2(8, 10)), Color(1.0, 0.72, 0.25, a))
