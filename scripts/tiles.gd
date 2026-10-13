class_name Tiles
extends RefCounted
## 地形タイルの定義。絵はコードで塗った仮のものなので、あとで手描きのタイル画像に差し替える。
## 差し替えるときは get_tileset() の画像部分だけを読み込みに変えればよい（番号はそのまま）。

const SIZE := 32

const DIRT := 0
const ROCK := 1
const AMBER := 2
const BEDROCK := 3
const LIVING_ROOT := 4
const BARK := 5
const LEAF := 6
const GROUND := 7
const COUNT := 8

## 掘るのに必要な打撃の合計（つるはしの強さぶん減っていく）
const HARDNESS := {DIRT: 1, ROCK: 4, AMBER: 3, BARK: 2}
## 掘ったときに落ちる材料
const DROPS := {ROCK: "stone", AMBER: "amber", BARK: "bark"}

static var _tileset: TileSet


static func is_breakable(id: int) -> bool:
	return HARDNESS.has(id)


static func get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var img := Image.create(SIZE * COUNT, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in COUNT:
		_paint(img, i, rng)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(src, 0)

	var h := SIZE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var thin := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 8), Vector2(-h, -h + 8)])
	for i in COUNT:
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		if i == LEAF:
			# 葉っぱの足場は下からすり抜けて上に乗れる
			td.set_collision_polygon_points(0, 0, thin)
			td.set_collision_polygon_one_way(0, 0, true)
		else:
			td.set_collision_polygon_points(0, 0, full)
	_tileset = ts
	return ts


static func _paint(img: Image, i: int, rng: RandomNumberGenerator) -> void:
	var base := Color(0, 0, 0, 0)
	match i:
		DIRT: base = Color(0.38, 0.26, 0.17)
		ROCK: base = Color(0.4, 0.4, 0.44)
		AMBER: base = Color(0.2, 0.18, 0.18)  # 黒い母岩に琥珀色の結晶
		BEDROCK: base = Color(0.12, 0.1, 0.1)
		LIVING_ROOT: base = Color(0.45, 0.32, 0.2)
		BARK: base = Color(0.55, 0.37, 0.22)
		GROUND: base = Color(0.35, 0.27, 0.18)
	var ox := i * SIZE
	for y in SIZE:
		for x in SIZE:
			var c := base
			if base.a > 0.0:
				c = base.darkened(rng.randf() * 0.14)
				# 縁を少し暗くしてタイルの境目を見やすくする
				if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
					c = c.darkened(0.25)
			img.set_pixel(ox + x, y, c)

	match i:
		AMBER:
			for k in 4:
				var cx := rng.randi_range(6, SIZE - 7)
				var cy := rng.randi_range(6, SIZE - 7)
				_diamond(img, ox + cx, cy, rng.randi_range(3, 5), Color(1.0, 0.7, 0.2))
				_diamond(img, ox + cx, cy - 1, 1, Color(1.0, 0.93, 0.7))
		ROCK:
			for k in 5:
				_diamond(img, ox + rng.randi_range(4, SIZE - 5), rng.randi_range(4, SIZE - 5), rng.randi_range(2, 4), Color(0.52, 0.52, 0.56))
		DIRT:
			for k in 6:
				img.set_pixel(ox + rng.randi_range(2, SIZE - 3), rng.randi_range(2, SIZE - 3), Color(0.5, 0.38, 0.27))
		LIVING_ROOT:
			for x in range(0, SIZE, 6):
				for y in SIZE:
					img.set_pixel(ox + x, y, base.lightened(0.15))
		BARK:
			for y in range(3, SIZE, 7):
				for x in range(2, SIZE - 2):
					img.set_pixel(ox + x, y, base.darkened(0.3))
		LEAF:
			for y in 9:
				for x in SIZE:
					var g := Color(0.35, 0.6, 0.25) if y < 7 else Color(0.25, 0.42, 0.18)
					img.set_pixel(ox + x, y, g)
			for x in range(0, SIZE, 2):
				img.set_pixel(ox + x, 3, Color(0.5, 0.75, 0.35))
		GROUND:
			for y in 5:
				for x in SIZE:
					img.set_pixel(ox + x, y, Color(0.36, 0.55, 0.25).darkened(rng.randf() * 0.2))


static func _diamond(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		var w := r - absi(dy)
		for dx in range(-w, w + 1):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)
