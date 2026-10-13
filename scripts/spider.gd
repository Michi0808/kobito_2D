class_name Spider
extends Creature
## 待ち伏せして跳びかかってくる小さなクモ。糸を落とす。

var cooldown := 1.0


func _setup() -> void:
	hp = 4
	size = Vector2(20, 14)
	drops = {"silk": 1}


func _ai(delta: float) -> void:
	cooldown -= delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		var p := Game.player as Player
		if p != null and is_instance_valid(p) and cooldown <= 0.0:
			var d := p.global_position - global_position
			if absf(d.x) < 230.0 and absf(d.y) < 120.0:
				dir = 1 if d.x > 0.0 else -1
				velocity = Vector2(dir * 190.0, -380.0)
				cooldown = randf_range(1.2, 2.0)


func _draw() -> void:
	var c := body_color(Color(0.25, 0.22, 0.3))
	for i in 4:
		var x := -6.0 + i * 4.0
		draw_line(Vector2(x, 0), Vector2(x * 2.2, 8), Color(0.15, 0.13, 0.18), 1.5)
	draw_circle(Vector2(0, 0), 7.0, c)
	draw_circle(Vector2(dir * 6.0, -2), 4.0, c)
	draw_circle(Vector2(dir * 8.0, -3), 1.2, Color(1.0, 0.4, 0.3))
