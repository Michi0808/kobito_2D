class_name Berry
extends RigidBody2D
## 森の実。枝にぶら下がっている間は止まっていて、叩くと落ちる（熟していない実は落ちない）。
## 落ちた実は転がり、主人公が歩いてぶつかると押され、ダッシュで体当たりすると弾け飛ぶ。
## 籠の中で止まると籠に入ったことになり、持ち物に加わる。

## 種類ごとの絵・直径（px）・重さ・持ち物の名前
const KINDS := {
	"black_s": {"tex": ["fruit_black_ripe_s"], "size": 22.0, "mass": 0.6, "item": "berry_black"},
	"black_m": {"tex": ["fruit_black_ripe_m_01", "fruit_black_ripe_m_02"], "size": 28.0, "mass": 1.0, "item": "berry_black"},
	"black_l": {"tex": ["fruit_black_ripe_l"], "size": 34.0, "mass": 1.5, "item": "berry_black"},
	"black_unripe": {"tex": ["fruit_black_unripe_m"], "size": 26.0, "mass": 1.0, "item": ""},
	"red": {"tex": ["fruit_red_ripe_m"], "size": 28.0, "mass": 1.0, "item": "berry_red"},
	"red_unripe": {"tex": ["fruit_red_unripe_m"], "size": 26.0, "mass": 1.0, "item": ""},
	"straw": {"tex": ["fruit_straw_ripe_l"], "size": 48.0, "mass": 3.0, "item": "berry_straw"},
}
const LAYER := 8  # 実どうしと地面・籠の壁に当たる。主人公（2）とはすり抜ける
const WALK_PUSH := 1.08  # 歩いて押したとき、主人公の速さの何倍で転がるか
const DASH_PUSH := Vector2(430.0, -240.0)  # 体当たりで弾ける速さ（重い実ほど小さい）

var kind := "black_m"
var radius := 14.0
var hanging := false
var in_basket := false
var settle := 0.0  # 籠の中で止まっている時間
var stem: Node2D = null  # ぶら下がっている間の茎（落ちたら消す）
var branch: Dictionary = {}  # ぶら下がっている枝
var art: Sprite2D
var _push_v: Variant = null
var _push_x: Variant = null
var _bump_cd := 0.0
var _wiggle := 0.0


func setup(k: String, hang: bool, rng: RandomNumberGenerator = null) -> Berry:
	kind = k
	hanging = hang
	var d: Dictionary = KINDS[k]
	radius = d["size"] / 2.0
	var names: Array = d["tex"]
	var pick: String = names[rng.randi_range(0, names.size() - 1) if rng != null else 0]
	art = Sprite2D.new()
	art.texture = ForestArt.tex(pick)
	var s: float = d["size"] / maxf(art.texture.get_width(), art.texture.get_height())
	art.scale = Vector2(s, s)
	add_child(art)
	if k == "straw":
		# 野苺はヘタを頭にのせる
		var calyx := Sprite2D.new()
		calyx.texture = ForestArt.tex("fruit_straw_calyx")
		var cs: float = d["size"] * 0.8 / calyx.texture.get_width()
		calyx.scale = Vector2(cs, cs)
		calyx.position = Vector2(0, -radius * 0.95)
		art.add_child(calyx)
		calyx.scale /= s
		calyx.position /= s
	return self


func _ready() -> void:
	add_to_group("berries")
	collision_layer = LAYER
	collision_mask = 1 | LAYER | ForestLevel.ITEM_WALL
	mass = KINDS[kind]["mass"]
	angular_damp = 1.5
	linear_damp = 0.2
	var mat := PhysicsMaterial.new()
	mat.friction = 0.7
	mat.bounce = 0.25
	physics_material_override = mat
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius * 0.92
	cs.shape = sh
	add_child(cs)
	if hanging:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true


func ripe() -> bool:
	return KINDS[kind]["item"] != ""


func item() -> String:
	return KINDS[kind]["item"]


## 攻撃が当たった（Player から呼ばれる）。何か起きたら true
func on_hit(_power: int, dir: Vector2, _from: Vector2) -> bool:
	if in_basket:
		return false
	if hanging:
		if dir.y > 0.0:
			# 上から下へ叩いたときは枝に当たる（枝ごと揺れて落ちる）
			return false
		if not ripe():
			_wiggle = 0.4
			if Game.level != null and Game.level.has_method("note_unripe"):
				Game.level.note_unripe()
			return true
		drop()
		return true
	# 落ちている実を叩くと、叩いた向きに転がる
	sleeping = false
	var heavy: float = KINDS[kind]["mass"]
	_push_v = Vector2(dir.x * 260.0, -150.0 if dir.y >= 0.0 else -260.0) / sqrt(heavy)
	if dir.y > 0.0:
		_push_v = Vector2(randf_range(-60.0, 60.0), -120.0)
	return true


## 枝から外れて落ちる
func drop(delay := 0.0) -> void:
	if not hanging:
		return
	hanging = false
	if delay > 0.0:
		_wiggle = delay
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self):
			return
	if stem != null and is_instance_valid(stem):
		stem.queue_free()
	stem = null
	freeze = false
	sleeping = false
	_push_v = Vector2(randf_range(-30.0, 30.0), 0.0)


func put_in_basket() -> void:
	in_basket = true
	set_deferred("freeze_mode", RigidBody2D.FREEZE_MODE_STATIC)
	set_deferred("freeze", true)


func _physics_process(delta: float) -> void:
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	if _wiggle > 0.0:
		_wiggle -= delta
		art.rotation = sin(_wiggle * 40.0) * 0.18
	elif hanging:
		art.rotation = 0.0
	if hanging or in_basket:
		return
	var p := Game.player as Player
	if p == null or not is_instance_valid(p) or p.hp <= 0:
		return
	var d := global_position - p.global_position
	var reach := Vector2(Player.BODY.x / 2.0 + radius * 0.85, Player.BODY.y / 2.0 + radius * 0.6)
	if absf(d.x) >= reach.x or absf(d.y) >= reach.y:
		return
	var dir := signf(d.x) if absf(d.x) > 1.0 else float(p.facing)
	var heavy: float = KINDS[kind]["mass"]
	if p.dash_t > 0.0 and signf(p.velocity.x) == dir:
		# 体当たり：重い実ほど飛ばない
		if _bump_cd <= 0.0:
			_bump_cd = 0.25
			_push_v = Vector2(DASH_PUSH.x * dir, DASH_PUSH.y) / sqrt(heavy)
			sleeping = false
	elif absf(p.velocity.x) > 10.0 and signf(p.velocity.x) == dir:
		# 歩いて押す：主人公より少し速く転がって前に出る
		_push_x = p.velocity.x * WALK_PUSH
		sleeping = false
	else:
		# 止まっている主人公に重なったら、そっと押し出す
		_push_x = dir * 40.0
		sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _push_v != null:
		state.linear_velocity = _push_v
		state.angular_velocity = (_push_v as Vector2).x / radius
		_push_v = null
	elif _push_x != null:
		var v := state.linear_velocity
		var want: float = _push_x
		if absf(v.x) < absf(want) or signf(v.x) != signf(want):
			v.x = want
			state.linear_velocity = v
			state.angular_velocity = want / radius
		_push_x = null
