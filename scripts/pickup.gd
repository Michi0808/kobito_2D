class_name Pickup
extends Area2D
## 落ちている材料。近づくと吸い寄せられて拾える。is_bag は前回倒れたときの落とし物の袋。

var items: Dictionary = {}
var is_bag := false
var vel := Vector2.ZERO
var t := 0.0


func setup(it: Dictionary, bag := false) -> Pickup:
	items = it
	is_bag = bag
	return self


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 10.0
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if not is_bag:
		vel = Vector2(randf_range(-70.0, 70.0), -170.0)


func _physics_process(delta: float) -> void:
	t += delta
	var p := Game.player as Player
	if p != null and is_instance_valid(p) and p.hp > 0 and t > 0.35 and global_position.distance_to(p.global_position) < 80.0:
		global_position = global_position.move_toward(p.global_position, 380.0 * delta)
	elif vel != Vector2.ZERO:
		vel.y = minf(vel.y + 900.0 * delta, 420.0)
		var step := vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0, 8))
		q.collision_mask = 1
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position += step
		else:
			global_position = hit["position"] - Vector2(0, 8)
			vel = Vector2.ZERO
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	for id in items:
		Game.add_item(id, int(items[id]))
	if is_bag:
		Game.lost_bag = {}
		Game.post("落とし物の袋を拾った：%s" % Game.cost_text(items))
	queue_free()


func _draw() -> void:
	var bob := sin(t * 4.0) * 2.0 if vel == Vector2.ZERO else 0.0
	if is_bag:
		draw_circle(Vector2(0, bob), 9.0, Color(0.6, 0.45, 0.28))
		draw_rect(Rect2(-4, -10 + bob, 8, 4), Color(0.45, 0.3, 0.18))
		return
	var id: String = items.keys()[0]
	var c: Color = Game.ITEM_COLORS.get(id, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -7 + bob), Vector2(6, bob), Vector2(0, 7 + bob), Vector2(-6, bob)]), c)
	draw_circle(Vector2(-1.5, -2 + bob), 1.5, Color(1, 1, 1, 0.7))
