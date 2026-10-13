class_name Ant
extends Creature
## 縄張りを歩き回るアリに似た虫。殻を落とす。

const SPEED := 55.0


func _setup() -> void:
	hp = 3
	size = Vector2(26, 14)
	drops = {"shell": 1}


func _ai(_delta: float) -> void:
	if is_on_wall() or (is_on_floor() and not ground_ahead(dir * (size.x / 2.0 + 4.0))):
		dir = -dir
	velocity.x = dir * SPEED


func _draw() -> void:
	var c := body_color(Color(0.55, 0.22, 0.14))
	var f := float(dir)
	for i in 3:
		var x := -8.0 + i * 8.0
		draw_line(Vector2(x, 2), Vector2(x - 4, 8), Color(0.2, 0.1, 0.06), 1.5)
		draw_line(Vector2(x, 2), Vector2(x + 4, 8), Color(0.2, 0.1, 0.06), 1.5)
	draw_circle(Vector2(-f * 8, 0), 6.0, c)
	draw_circle(Vector2(0, 0), 4.0, c)
	draw_circle(Vector2(f * 8, -1), 5.0, c)
	draw_line(Vector2(f * 11, -4), Vector2(f * 16, -10), c, 1.5)
	draw_circle(Vector2(f * 10, -2), 1.2, Color(1, 1, 1))
