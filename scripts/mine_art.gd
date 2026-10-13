class_name MineArt
extends RefCounted
## 坑道の手描き素材（art/mine/）をまとめて読み込む。
## 絵は 1マス 64px で描き、ゲームの中では半分（32 = Tiles.SIZE）に縮めて使う。
## 同じ名前・同じ大きさの PNG で上書きすれば、コードを触らずに絵が差し替わる。
## 寸法と並びの決まりは art/mine/README.md を参照。

const DIR := "res://art/mine/"
const CELL := 64
const SCALE := float(Tiles.SIZE) / CELL

## 見た目用タイルセットの中の番号
const SRC_TERRAIN := 0  # terrain.png      4×4（番号 = 上1 + 右2 + 下4 + 左8 が続いているか）
const SRC_FILL := 1  # terrain_fill.png 4×1（四方とも続いているマスの柄違い）
const SRC_ORE := {Tiles.ROCK: 2, Tiles.AMBER: 3, Tiles.BARK: 4, Tiles.LIVING_ROOT: 5, Tiles.BEDROCK: 6}
const SRC_PLATFORM := {Tiles.LEAF: 7, Tiles.PLANK: 8}

const ORE_FILES := {2: "ore_rock", 3: "ore_amber", 4: "ore_bark", 5: "ore_root", 6: "ore_bedrock"}
const PLATFORM_FILES := {7: "platform_leaf", 8: "platform_plank"}

static var _tileset: TileSet


static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


static func get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	_add_sheet(ts, SRC_TERRAIN, "terrain", Vector2i(4, 4))
	_add_sheet(ts, SRC_FILL, "terrain_fill", Vector2i(4, 1))
	for id in ORE_FILES:
		_add_sheet(ts, id, ORE_FILES[id], Vector2i(2, 1))
	for id in PLATFORM_FILES:
		_add_sheet(ts, id, PLATFORM_FILES[id], Vector2i(3, 1))
	_tileset = ts
	return ts


static func _add_sheet(ts: TileSet, id: int, file: String, cells: Vector2i) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = tex(file)
	src.texture_region_size = Vector2i(CELL, CELL)
	ts.add_source(src, id)
	for y in cells.y:
		for x in cells.x:
			src.create_tile(Vector2i(x, y))


## 置き物（飾り・はしご・中景など）。足元（下端の中央）を pos に合わせる
static func sprite(name: String, pos: Vector2, hang := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(name)
	s.scale = Vector2(SCALE, SCALE)
	s.centered = true
	var h := s.texture.get_height() * SCALE
	s.position = pos + Vector2(0, h / 2.0 if hang else -h / 2.0)
	return s


## 灯り（ランタン・結晶）
static func light(color: Color, size: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	l.texture = gt
	l.texture_scale = size
	l.color = color
	l.energy = energy
	return l
