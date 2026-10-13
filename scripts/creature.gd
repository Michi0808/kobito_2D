class_name Creature
extends CharacterBody2D
## 地上（坑道）の野生の生き物の共通部分。倒すと材料を落とす。鉱石は落とさない（鉱石は掘ってだけ手に入る）。

const GRAVITY := 1100.0

var hp := 3
var size := Vector2(24, 14)
var contact_damage := 1
var drops: Dictionary = {}
var flash := 0.0
var stun := 0.0
var dir := -1
var dead := false


func _ready() -> void:
	_setup()
	add_to_group("creatures")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)


## 種類ごとの体力・大きさ・落とす材料を決める
func _setup() -> void:
	pass


func _ai(_delta: float) -> void:
	pass


func knockback_scale() -> float:
	return 1.0


func hurt(dmg: int, from: Vector2) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	var s := signf(global_position.x - from.x)
	if s == 0.0:
		s = 1.0
	velocity = Vector2(s * 200.0, -140.0) * knockback_scale()
	stun = 0.25
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	if Game.level != null and Game.level.has_method("spawn_pickup"):
		for id in drops:
			Game.level.spawn_pickup(global_position, {id: drops[id]})
	_on_die()
	queue_free()


func _on_die() -> void:
	pass


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)
	if stun > 0.0:
		stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	else:
		_ai(delta)
	move_and_slide()
	_touch_player()
	queue_redraw()


func _touch_player() -> void:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p) or contact_damage <= 0:
		return
	var d := p.global_position - global_position
	if absf(d.x) < size.x / 2.0 + 8.0 and absf(d.y) < size.y / 2.0 + Player.BODY.y / 2.0 - 2.0:
		p.take_damage(contact_damage, global_position)


func ground_ahead(dx: float) -> bool:
	var from := global_position + Vector2(dx, 0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, size.y / 2.0 + 12.0))
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func body_color(c: Color) -> Color:
	return Color(1, 1, 1) if flash > 0.0 else c
