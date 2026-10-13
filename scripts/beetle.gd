class_name Beetle
extends Creature
## 坑道の主。大きな甲虫。ためてから突進し、壁にぶつかると目を回す（そこが攻めどき）。

enum State { WALK, WINDUP, CHARGE, DIZZY }

var state := State.WALK
var t := 0.0
var max_hp := 24


func _setup() -> void:
	hp = 24
	max_hp = 24
	size = Vector2(64, 36)
	drops = {"shell": 5, "silk": 2}
	Game.boss = self


func knockback_scale() -> float:
	return 0.35 if state == State.DIZZY else 0.0


func hurt(dmg: int, from: Vector2) -> void:
	# 目を回している間は2倍効く
	super.hurt(dmg * (2 if state == State.DIZZY else 1), from)
	stun = 0.0


func _ai(delta: float) -> void:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p):
		return
	t += delta
	match state:
		State.WALK:
			dir = 1 if p.global_position.x > global_position.x else -1
			velocity.x = dir * 45.0
			if t > 1.8 and absf(p.global_position.y - global_position.y) < 90.0:
				state = State.WINDUP
				t = 0.0
		State.WINDUP:
			velocity.x = 0.0
			if t > 0.7:
				state = State.CHARGE
				t = 0.0
		State.CHARGE:
			velocity.x = dir * 330.0
			if (t > 0.1 and is_on_wall()) or t > 3.0:
				state = State.DIZZY
				t = 0.0
		State.DIZZY:
			velocity.x = 0.0
			if t > 1.6:
				state = State.WALK
				t = 0.0


func _on_die() -> void:
	Game.boss = null
	Game.boss_defeated = true
	Game.post("坑道の主を倒した。奥の空洞が静かになった。")


func _draw() -> void:
	var c := body_color(Color(0.18, 0.28, 0.24))
	if state == State.WINDUP and int(t * 12.0) % 2 == 0:
		c = Color(0.6, 0.25, 0.2)
	var f := float(dir)
	for i in 3:
		var x := -18.0 + i * 18.0
		draw_line(Vector2(x, 10), Vector2(x - 6, 18), Color(0.1, 0.1, 0.08), 3.0)
		draw_line(Vector2(x, 10), Vector2(x + 6, 18), Color(0.1, 0.1, 0.08), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32, 12), Vector2(-28, -6), Vector2(-14, -18), Vector2(10, -18),
		Vector2(26, -8), Vector2(32, 12)]), c)
	draw_line(Vector2(0, -18), Vector2(0, 12), c.darkened(0.4), 2.0)
	draw_circle(Vector2(f * 30, 2), 8.0, c.darkened(0.2))
	draw_line(Vector2(f * 34, 0), Vector2(f * 46, -14), c.lightened(0.2), 4.0)
	draw_circle(Vector2(f * 33, 0), 2.0, Color(1, 0.9, 0.6))
	if state == State.DIZZY:
		for i in 3:
			var a := t * 4.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 14.0, -28 + sin(a) * 4.0), 3.0, Color(1, 0.9, 0.4))
