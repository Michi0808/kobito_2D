extends Node
## 試作全体の状態（持ち物・道具・建築物）と、村と坑道の切り替えを持つ。
## 自動読み込み（Autoload）で常に存在し、どの場面からも Game.xxx で参照できる。

const SAVE_PATH := "user://save.json"
const VILLAGE_SCENE := "res://scenes/village.tscn"
const MINE_SCENE := "res://scenes/mine.tscn"
const FOREST_SCENE := "res://scenes/forest.tscn"

const ITEM_ORDER := ["bark", "stone", "amber", "shell", "silk", "berry_black", "berry_red", "berry_straw"]
const ITEM_NAMES := {
	"bark": "樹皮", "stone": "石", "amber": "琥珀鉱", "shell": "殻", "silk": "糸",
	"berry_black": "黒い木苺", "berry_red": "赤い木苺", "berry_straw": "野苺",
}
const ITEM_COLORS := {
	"bark": Color(0.62, 0.42, 0.25),
	"stone": Color(0.66, 0.66, 0.7),
	"amber": Color(1.0, 0.68, 0.18),
	"shell": Color(0.9, 0.82, 0.62),
	"silk": Color(0.96, 0.96, 1.0),
	"berry_black": Color(0.3, 0.18, 0.35),
	"berry_red": Color(0.85, 0.2, 0.25),
	"berry_straw": Color(0.9, 0.25, 0.2),
}
const START_INV := {"bark": 8, "stone": 4, "amber": 0, "shell": 0, "silk": 0, "berry_black": 0, "berry_red": 0, "berry_straw": 0}

## 工房（作業台）で作れるもの
const RECIPES := [
	{"id": "lantern", "name": "ランタン", "cost": {"amber": 3, "shell": 2, "silk": 1}, "desc": "坑道の暗い奥まで照らせる"},
	{"id": "pick2", "name": "つるはし強化", "cost": {"stone": 6, "amber": 2}, "desc": "掘る力と攻撃が2倍になる"},
]

signal inventory_changed
signal message_posted(text: String)

var inv: Dictionary = START_INV.duplicate()
## 今回の坑道で手に入れた分（倒れたときに半分を落とす）
var run_gain: Dictionary = {}
## 前回倒れたときに坑道へ落とした材料
var lost_bag: Dictionary = {}
var has_lantern := false
var pick_level := 1
var boss_defeated := false
## 村に置いた部品 [{kind, x, y}]
var built: Array = []
var max_hp := 5

var player: Node = null
var level: Node = null
var boss: Node = null
var ui_theme: Theme
## 場面が切り替わった直後に表示するメッセージ
var queued_message := ""
## どこから村へ戻ってきたか（"forest" なら森への道の前に立つ）
var arrived_from := ""
var saving_enabled := true
var bgm: AudioStreamPlayer
var bgm_path := ""


func _ready() -> void:
	_setup_input()
	_setup_theme()
	_setup_bgm()
	load_game()
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		add_child(load("res://tests/smoke.gd").new())
	elif "--shots" in args:
		add_child(load("res://tests/shots.gd").new())
	elif "--poses" in args:
		add_child(load("res://tests/poses.gd").new())


# ---- 持ち物 ----

func add_item(id: String, amount: int, from_run := true) -> void:
	inv[id] = int(inv.get(id, 0)) + amount
	if from_run:
		run_gain[id] = int(run_gain.get(id, 0)) + amount
	inventory_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if int(inv.get(id, 0)) < int(cost[id]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for id in cost:
		inv[id] = int(inv[id]) - int(cost[id])
	inventory_changed.emit()
	return true


func refund(cost: Dictionary) -> void:
	for id in cost:
		inv[id] = int(inv.get(id, 0)) + int(cost[id])
	inventory_changed.emit()


func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in ITEM_ORDER:
		if cost.has(id):
			parts.append("%s×%d" % [ITEM_NAMES[id], int(cost[id])])
	return "・".join(parts)


# ---- 工房 ----

func recipe_done(id: String) -> bool:
	match id:
		"lantern":
			return has_lantern
		"pick2":
			return pick_level >= 2
	return false


func craft(id: String) -> bool:
	for r in RECIPES:
		if r["id"] != id or recipe_done(id):
			continue
		if not spend(r["cost"]):
			post("材料が足りない：%s" % cost_text(r["cost"]))
			return false
		match id:
			"lantern":
				has_lantern = true
				post("ランタンができた。坑道の暗い奥まで照らせる。")
			"pick2":
				pick_level = 2
				post("つるはしを鍛え直した。掘る力と攻撃が上がった。")
		save_game()
		return true
	return false


# ---- メッセージ ----

func post(text: String) -> void:
	message_posted.emit(text)


func post_after_scene_change(text: String) -> void:
	queued_message = text


# ---- 場面の切り替え ----

func goto_mine() -> void:
	save_game()
	run_gain = {}
	get_tree().call_deferred("change_scene_to_file", MINE_SCENE)


func goto_forest() -> void:
	save_game()
	run_gain = {}
	get_tree().call_deferred("change_scene_to_file", FOREST_SCENE)


func goto_village() -> void:
	get_tree().call_deferred("change_scene_to_file", VILLAGE_SCENE)


## 出口か帰還で、持ち物を全部持って村へ戻る
func finish_run() -> void:
	arrived_from = "forest" if level != null and level.name == "Forest" else ""
	var got := cost_text(run_gain)
	post_after_scene_change("村に戻った。" + ("持ち帰り：" + got if got != "" else "今回の収穫はなし。"))
	run_gain = {}
	save_game()
	goto_village()


## 坑道で倒れた。仲間に助けられて村へ戻る。今回の収穫の半分を坑道に落とす。
func player_fell() -> void:
	var lost := {}
	for id in run_gain:
		var n := floori(int(run_gain[id]) / 2.0)
		if n > 0:
			lost[id] = n
			inv[id] = int(inv[id]) - n
			lost_bag[id] = int(lost_bag.get(id, 0)) + n
	run_gain = {}
	var text := "倒れて、仲間に村まで運ばれた。"
	if not lost.is_empty():
		text += "落とした材料（%s）は次に坑道へ入ったとき入口近くで拾える。" % cost_text(lost)
	post_after_scene_change(text)
	save_game()
	get_tree().create_timer(1.0).timeout.connect(goto_village)


# ---- 保存 ----

func save_game() -> void:
	if not saving_enabled:
		return
	var data := {
		"inv": inv, "lost_bag": lost_bag, "has_lantern": has_lantern,
		"pick_level": pick_level, "boss_defeated": boss_defeated, "built": built,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for id in ITEM_ORDER:
		inv[id] = int(data.get("inv", {}).get(id, 0))
	for id in data.get("lost_bag", {}):
		lost_bag[id] = int(data["lost_bag"][id])
	has_lantern = bool(data.get("has_lantern", false))
	pick_level = int(data.get("pick_level", 1))
	boss_defeated = bool(data.get("boss_defeated", false))
	built = []
	for b in data.get("built", []):
		built.append({"kind": str(b["kind"]), "x": int(b["x"]), "y": int(b["y"])})


func reset_state() -> void:
	inv = START_INV.duplicate()
	run_gain = {}
	lost_bag = {}
	has_lantern = false
	pick_level = 1
	boss_defeated = false
	built = []
	inventory_changed.emit()


# ---- 入力と見た目の初期設定 ----

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("jump", [KEY_SPACE, KEY_Z], [JOY_BUTTON_A])
	_add_action("attack", [KEY_J, KEY_X], [JOY_BUTTON_X])
	_add_action("dash", [KEY_K, KEY_C, KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B])
	_add_action("interact", [KEY_E], [JOY_BUTTON_Y])
	_add_action("build_mode", [KEY_B], [JOY_BUTTON_BACK])


func _add_action(action: String, keys: Array, buttons: Array = [], axis := -1, axis_dir := 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	if axis >= 0:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = axis_dir
		InputMap.action_add_event(action, m)


## 村でも坑道でも流れる曲。差し替えるときはここのファイル名を変える
const MAIN_BGM := "res://audio/rootlight_village_recorded.ogg"
## 森の曲（audio/village_under_world_tree.mid を音にしたもの）
const FOREST_BGM := "res://audio/village_under_world_tree.ogg"
## まだ使っていない曲（坑道用・夜用）。場面や時間で切り替えるときに使う
const MINE_BGM := "res://audio/amber_veins_mine_8bit.ogg"
const NIGHT_BGM := "res://audio/rootlight_village_evening_8bit.ogg"


func _setup_bgm() -> void:
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -6.0
	bgm.finished.connect(bgm.play)
	add_child(bgm)
	play_bgm(MAIN_BGM)


## 曲を切り替える。同じ曲が流れていればそのまま続ける
func play_bgm(path: String) -> void:
	if bgm_path == path or not ResourceLoader.exists(path):
		return
	bgm_path = path
	var stream: AudioStream = load(path)
	if "loop" in stream:
		stream.loop = true
	bgm.stream = stream
	bgm.play()


func _setup_theme() -> void:
	ui_theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	ui_theme.set_constant("outline_size", "Label", 6)
	ui_theme.set_color("font_outline_color", "Label", Color(0.08, 0.05, 0.03))


func _exit_tree() -> void:
	# 終了時に曲を手放しておく（残っていると終了時に警告が出る）
	bgm.stop()
	bgm.stream = null
