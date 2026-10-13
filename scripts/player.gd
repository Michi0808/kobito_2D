class_name Player
extends CharacterBody2D
## 主人公（リネ族の小人）。走る・跳ぶ・滑空・ダッシュ・攻撃（＝つるはしで掘る）。
## 絵は仮の図形。あとでパーツ分けした手描き絵＋Skeleton2D に差し替える。

const RUN_SPEED := 175.0
const ACCEL := 1500.0
const FRICTION := 1800.0
const GRAVITY := 1150.0
const JUMP_VELOCITY := -470.0
const MAX_FALL := 560.0
const GLIDE_FALL := 75.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.55
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const ATTACK_COOLDOWN := 0.26
const BODY := Vector2(18, 26)

var hp := 5
var facing := 1
var invuln := 0.0
var knock := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var coyote := 0.0
var jump_buf := 0.0
var attack_cd := 0.0
var attack_show := 0.0
var attack_dir := Vector2.RIGHT
var gliding := false
var air_dash_used := false
var controls_locked := false
var camera: Camera2D
var light: PointLight2D


func _ready() -> void:
	Game.player = self
	hp = Game.max_hp
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = BODY
	cs.shape = sh
	add_child(cs)

	# ホロウナイト風：少し遅れて追いかけ、向いている方を多めに見せるカメラ
	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.drag_vertical_enabled = true
	camera.drag_top_margin = 0.15
	camera.drag_bottom_margin = 0.1
	add_child(camera)

	light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	light.texture = gt
	add_child(light)
	update_light()


func _exit_tree() -> void:
	if Game.player == self:
		Game.player = null


func update_light() -> void:
	if Game.has_lantern:
		light.texture_scale = 2.6
		light.color = Color(1.0, 0.78, 0.45)
		light.energy = 1.15
	else:
		light.texture_scale = 0.9
		light.color = Color(0.85, 0.8, 0.75)
		light.energy = 0.8


func set_camera_limits(r: Rect2) -> void:
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	attack_show = maxf(attack_show - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)

	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_dash_used = false
	else:
		coyote -= delta

	var input_x := 0.0 if controls_locked else Input.get_axis("move_left", "move_right")
	if not controls_locked and Input.is_action_just_pressed("jump"):
		jump_buf = JUMP_BUFFER
	else:
		jump_buf -= delta

	if knock > 0.0:
		knock -= delta
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		gliding = false
	elif dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		if input_x != 0.0:
			facing = 1 if input_x > 0.0 else -1
		var rate := ACCEL if input_x != 0.0 else FRICTION
		velocity.x = move_toward(velocity.x, input_x * RUN_SPEED, rate * delta)

		if jump_buf > 0.0 and coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buf = 0.0
			coyote = 0.0
		# ボタンを早く離すと低いジャンプになる
		var holding_jump := Input.is_action_pressed("jump") and not controls_locked
		if velocity.y < 0.0 and not holding_jump:
			velocity.y += GRAVITY * 1.6 * delta
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

		# 落ちている間ジャンプを押し続けると葉のグライダーで滑空
		gliding = not on_floor and velocity.y > 0.0 and holding_jump
		if gliding:
			velocity.y = minf(velocity.y, GLIDE_FALL)

		if not controls_locked:
			if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (on_floor or not air_dash_used):
				dash_t = DASH_TIME
				dash_cd = DASH_COOLDOWN
				if not on_floor:
					air_dash_used = true
			if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
				_attack()

	if not controls_locked and Input.is_action_just_pressed("interact"):
		if Game.level != null and Game.level.has_method("on_interact"):
			Game.level.on_interact()

	move_and_slide()
	camera.offset.x = lerpf(camera.offset.x, facing * 48.0, 2.0 * delta)
	queue_redraw()


func _attack() -> void:
	attack_cd = ATTACK_COOLDOWN
	attack_show = 0.12
	if Input.is_action_pressed("up"):
		attack_dir = Vector2.UP
	elif Input.is_action_pressed("down"):
		attack_dir = Vector2.DOWN
	else:
		attack_dir = Vector2(facing, 0)
	var power: int = Game.pick_level

	# 生き物に当たったか
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 26) if attack_dir.y == 0.0 else Vector2(26, 34)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + attack_dir * 24.0)
	q.collision_mask = 4
	var hit_creature := false
	for h in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var c: Object = h["collider"]
		if is_instance_valid(c) and c is Creature:
			(c as Creature).hurt(power, global_position)
			hit_creature = true
	if hit_creature:
		if attack_dir == Vector2.DOWN and not is_on_floor():
			# 下突きで跳ね返る（ホロウナイトのホッピング）
			velocity.y = -380.0
			air_dash_used = false
		elif attack_dir.y == 0.0:
			velocity.x = -facing * 140.0
		return

	# 何もいなければ、その方向の壁を掘る
	if Game.level != null and Game.level.has_method("hit_tile"):
		if Game.level.hit_tile(global_position + attack_dir * 26.0, power) and attack_dir.y == 0.0:
			velocity.x = -facing * 40.0


func take_damage(amount: int, from: Vector2) -> void:
	if invuln > 0.0 or hp <= 0:
		return
	hp -= amount
	invuln = 1.0
	knock = 0.22
	dash_t = 0.0
	velocity = Vector2((1.0 if global_position.x >= from.x else -1.0) * 230.0, -230.0)
	if hp <= 0:
		controls_locked = true
		if Game.level != null and Game.level.has_method("on_player_down"):
			Game.level.on_player_down()


func heal_full() -> void:
	hp = Game.max_hp


func _draw() -> void:
	var a := 1.0
	if invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		a = 0.35
	if hp <= 0:
		a = 0.5
	var f := float(facing)
	# 葉のグライダー
	if gliding:
		draw_colored_polygon(PackedVector2Array([Vector2(-22, -24), Vector2(0, -34), Vector2(22, -24), Vector2(0, -27)]), Color(0.4, 0.7, 0.3, a))
		draw_line(Vector2(0, -28), Vector2(0, -12), Color(0.35, 0.25, 0.15, a), 1.5)
	# 足
	draw_rect(Rect2(-6, 9, 4, 4), Color(0.3, 0.2, 0.12, a))
	draw_rect(Rect2(2, 9, 4, 4), Color(0.3, 0.2, 0.12, a))
	# 胴（麻布の服）
	draw_rect(Rect2(-7, -4, 14, 14), Color(0.42, 0.52, 0.38, a))
	draw_rect(Rect2(-7, 4, 14, 2), Color(0.55, 0.38, 0.22, a))
	# 頭とどんぐりの帽子
	draw_circle(Vector2(0, -9), 7.0, Color(0.96, 0.82, 0.68, a))
	draw_rect(Rect2(-8, -18, 16, 6), Color(0.5, 0.33, 0.18, a))
	draw_rect(Rect2(-1, -21, 2, 3), Color(0.4, 0.26, 0.14, a))
	draw_circle(Vector2(f * 3.0, -9), 1.5, Color(0.1, 0.07, 0.05, a))
	# ランタン
	if Game.has_lantern:
		draw_line(Vector2(-f * 7, -2), Vector2(-f * 10, 2), Color(0.3, 0.2, 0.1, a), 1.0)
		draw_circle(Vector2(-f * 10, 5), 3.5, Color(1.0, 0.72, 0.25, a))
	# つるはしの振り
	if attack_show > 0.0:
		var ang := attack_dir.angle()
		draw_arc(attack_dir * 16.0, 16.0, ang - 1.1, ang + 1.1, 10, Color(1.0, 0.95, 0.75, 0.85), 3.0)
