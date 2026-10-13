class_name BuildSystem
extends Node2D
## 村の自由建築。手描きの部品（いまは仮の図形）を格子に吸着して置く。
## 施設は建物ではなく中核の道具で決まる：作業台を屋根と左右の壁で囲うと工房として働く。

const T := Tiles.SIZE
const PARTS := {
	"floor": {"name": "床", "cost": {"bark": 1}, "back": false, "solid": "oneway"},
	"wall": {"name": "壁", "cost": {"bark": 2}, "back": false, "solid": "full"},
	"door": {"name": "入口", "cost": {"bark": 2, "silk": 1}, "back": false, "solid": "none"},
	"roof": {"name": "屋根", "cost": {"bark": 1, "shell": 1}, "back": false, "solid": "oneway"},
	"back": {"name": "奥の壁", "cost": {"bark": 1}, "back": true, "solid": "none"},
	"bench": {"name": "作業台", "cost": {"stone": 3, "bark": 2}, "back": false, "solid": "none"},
	"lamp": {"name": "ランタン灯", "cost": {"amber": 1}, "back": false, "solid": "none"},
}
const ORDER := ["floor", "wall", "door", "roof", "back", "bench", "lamp"]

var active := false
var selected := 0
var area := Rect2i()
var map: TileMapLayer
var hud: HUD
## 置いた部品。キーは Vector3i(x, y, 0=手前 / 1=奥)
var parts: Dictionary = {}
var cursor := Vector2i.ZERO
var lamp_texture: GradientTexture2D


func setup(build_area: Rect2i, tile_map: TileMapLayer, the_hud: HUD) -> void:
	area = build_area
	map = tile_map
	hud = the_hud


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	lamp_texture = GradientTexture2D.new()
	lamp_texture.gradient = g
	lamp_texture.fill = GradientTexture2D.FILL_RADIAL
	lamp_texture.fill_from = Vector2(0.5, 0.5)
	lamp_texture.fill_to = Vector2(1.0, 0.5)
	# 保存していた建物を建て直す
	for b in Game.built:
		place(str(b["kind"]), Vector2i(int(b["x"]), int(b["y"])), false)


# ---- 置く・外す ----

func can_place(kind: String, cell: Vector2i) -> bool:
	if not area.has_point(cell):
		return false
	if map.get_cell_source_id(cell) != -1:
		return false
	var key := _key(kind, cell)
	if parts.has(key):
		return false
	if PARTS[kind]["solid"] == "full" and _overlaps_player(cell):
		return false
	if kind == "bench" and not _has_support(cell):
		return false
	return true


func place(kind: String, cell: Vector2i, pay := true) -> bool:
	if not can_place(kind, cell):
		return false
	if pay and not Game.spend(PARTS[kind]["cost"]):
		Game.post("材料が足りない：%s" % Game.cost_text(PARTS[kind]["cost"]))
		return false
	var node := BuiltPart.new()
	node.kind = kind
	node.position = Vector2(cell) * T
	node.z_index = -2 if PARTS[kind]["back"] else 0
	add_child(node)
	if PARTS[kind]["solid"] != "none":
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		if PARTS[kind]["solid"] == "full":
			sh.size = Vector2(T, T)
			cs.position = Vector2(T / 2.0, T / 2.0)
		else:
			sh.size = Vector2(T, 8)
			cs.position = Vector2(T / 2.0, 4)
			cs.one_way_collision = true
		cs.shape = sh
		body.add_child(cs)
		node.add_child(body)
	if kind == "lamp":
		var l := PointLight2D.new()
		l.texture = lamp_texture
		l.texture_scale = 3.0
		l.color = Color(1.0, 0.75, 0.4)
		l.energy = 0.9
		l.position = Vector2(T / 2.0, T / 2.0)
		node.add_child(l)
	parts[_key(kind, cell)] = node
	if pay:
		Game.built.append({"kind": kind, "x": cell.x, "y": cell.y})
		Game.save_game()
	refresh_benches()
	return true


func remove_at(cell: Vector2i) -> bool:
	for layer in [0, 1]:
		var key := Vector3i(cell.x, cell.y, layer)
		if not parts.has(key):
			continue
		var node: BuiltPart = parts[key]
		Game.refund(PARTS[node.kind]["cost"])
		parts.erase(key)
		node.queue_free()
		for i in Game.built.size():
			var b: Dictionary = Game.built[i]
			if int(b["x"]) == cell.x and int(b["y"]) == cell.y and (PARTS[b["kind"]]["back"] == (layer == 1)):
				Game.built.remove_at(i)
				break
		Game.save_game()
		refresh_benches()
		return true
	return false


func _key(kind: String, cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, cell.y, 1 if PARTS[kind]["back"] else 0)


func front_kind(cell: Vector2i) -> String:
	var key := Vector3i(cell.x, cell.y, 0)
	if parts.has(key):
		return (parts[key] as BuiltPart).kind
	return ""


func _has_support(cell: Vector2i) -> bool:
	var below := cell + Vector2i.DOWN
	return map.get_cell_source_id(below) != -1 or front_kind(below) in ["floor", "wall"]


func _overlaps_player(cell: Vector2i) -> bool:
	var p := Game.player as Player
	if p == null:
		return false
	var r := Rect2(Vector2(cell) * T, Vector2(T, T))
	return r.intersects(Rect2(p.global_position - Player.BODY / 2.0, Player.BODY))


# ---- 工房の判定 ----

## 作業台が「屋根（か上の床）と左右の壁（か入口）」で囲われていれば工房として働く
func is_workshop(cell: Vector2i) -> bool:
	var left := false
	var right := false
	var top := false
	for i in range(1, 10):
		if front_kind(cell + Vector2i(-i, 0)) in ["wall", "door"]:
			left = true
			break
	for i in range(1, 10):
		if front_kind(cell + Vector2i(i, 0)) in ["wall", "door"]:
			right = true
			break
	for i in range(1, 9):
		if front_kind(cell + Vector2i(0, -i)) in ["roof", "floor"]:
			top = true
			break
	return left and right and top


func refresh_benches() -> void:
	for key in parts:
		var node: BuiltPart = parts[key]
		if node.kind == "bench":
			node.working = is_workshop(Vector2i(key.x, key.y))
			node.queue_redraw()


## 近くにある作業台のマス。なければ null
func bench_near(pos: Vector2) -> Variant:
	for key in parts:
		var node: BuiltPart = parts[key]
		if node.kind == "bench" and (node.position + Vector2(T / 2.0, T / 2.0)).distance_to(pos) < 48.0:
			return Vector2i(key.x, key.y)
	return null


# ---- 建築モードの操作 ----

func toggle() -> void:
	active = not active
	_update_panel()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if hud != null and hud.is_craft_open():
		return
	if event.is_action_pressed("build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < ORDER.size():
			selected = n
			_update_panel()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				place(ORDER[selected], cursor)
			MOUSE_BUTTON_RIGHT:
				remove_at(cursor)
			MOUSE_BUTTON_WHEEL_UP:
				selected = (selected + ORDER.size() - 1) % ORDER.size()
				_update_panel()
			MOUSE_BUTTON_WHEEL_DOWN:
				selected = (selected + 1) % ORDER.size()
				_update_panel()


func _update_panel() -> void:
	if hud == null:
		return
	if not active:
		hud.show_build("")
		return
	var lines: PackedStringArray = ["【建築モード】 B で終了"]
	for i in ORDER.size():
		var k: String = ORDER[i]
		lines.append("%s %d %s（%s）" % ["▶" if i == selected else "　", i + 1, PARTS[k]["name"], Game.cost_text(PARTS[k]["cost"])])
	lines.append("左クリック：置く　右クリック：外す")
	lines.append("作業台を屋根と左右の壁で囲うと工房になる")
	hud.show_build("\n".join(lines))


func _process(_delta: float) -> void:
	if active:
		cursor = map.local_to_map(map.to_local(get_global_mouse_position()))
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var grid := Color(1, 1, 1, 0.08)
	for x in range(area.position.x, area.end.x + 1):
		draw_line(Vector2(x * T, area.position.y * T), Vector2(x * T, area.end.y * T), grid)
	for y in range(area.position.y, area.end.y + 1):
		draw_line(Vector2(area.position.x * T, y * T), Vector2(area.end.x * T, y * T), grid)
	var kind: String = ORDER[selected]
	var ok := can_place(kind, cursor) and Game.can_afford(PARTS[kind]["cost"])
	var c := Color(0.4, 1.0, 0.5, 0.35) if ok else Color(1.0, 0.35, 0.3, 0.35)
	draw_rect(Rect2(Vector2(cursor) * T, Vector2(T, T)), c)
	BuiltPart.draw_part(self, kind, Vector2(cursor) * T, 0.5, false)
