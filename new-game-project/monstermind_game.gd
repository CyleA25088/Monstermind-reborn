extends Node2D

## MonsterMind Reborn game controller.
## Rendering, input, economy, and monster updates are exposed through sibling
## nodes in node_2d.tscn while this controller keeps the existing game rules.

## Half-extents for a strict 2:1 dimetric/isometric game tile.
## A complete tile is 88 x 44 pixels; all drawing and picking use this same projection.
const TILE := Vector2(44.0, 22.0)
const COLS := 12
const ROWS := 8
const HUD_BOTTOM := 585.0
const NAVY := Color("#193b5a")
const BLUE := Color("#19b8d0")
const ORANGE := Color("#f28c38")
const GREEN := Color("#52c86b")

## Roads are visual infrastructure only. Each entry is a real isometric road
## cell; no road is drawn as a free-floating line between arbitrary points.
const ROAD_CELLS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
	Vector2i(2, 3), Vector2i(4, 3), Vector2i(6, 3), Vector2i(8, 3),
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
	Vector2i(6, 5), Vector2i(6, 6)
]

var ui_font: Font
var buildings: Array = []
var road_cells: Array[Vector2i] = []
var monsters: Array = []
var particles: Array = []
var numbers: Array = []
var resources := {"coins": 900, "energy": 0, "water": 0, "population": 0, "attack": 5}
var selected_card := "mint"
var selected_building := -1
var mission_time := 180.0
var score := 0
var tutorial := true
var won := false
var lost := false
var build_phase := true
var clock := 0.0
var adviser := "Starter town ready. Buy buildings from the shop and place them from INVENTORY."
var inventory := {"mint": 0, "power": 0, "water": 0, "home": 0, "store": 0, "defense": 0, "town": 0, "road": 0}
var inventory_open := false
var placement_item := ""
var context_open := false
var context_type := ""
var context_building := -1
var context_road := Vector2i(-1, -1)
var context_position := Vector2.ZERO
var move_mode := false
var monster_preview_grid := Vector2i(-1, -1)

@onready var input_router: MonsterMindInputRouter = $InputRouter
@onready var economy_system: MonsterMindEconomySystem = $EconomySystem
@onready var monster_system: MonsterMindMonsterSystem = $MonsterSystem
@onready var visual_system: MonsterMindVisualSystem = $VisualSystem

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	economy_system.controller = self
	monster_system.controller = self
	visual_system.controller = self
	input_router.input_received.connect(_handle_input)
	_make_city()
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if not tutorial and not won and not lost:
		economy_system.tick(delta)
		if not build_phase:
			mission_time = maxf(0.0, mission_time - delta)
		monster_system.tick(delta)
		if not build_phase and mission_time == 0.0:
			lost = true
	visual_system.tick(delta)
	queue_redraw()

func _make_city() -> void:
	# Compact starter layout based on the reference game's opening town:
	# one Town Hall, a few homes, and a Coin Mint connected by cell roads.
	buildings = [
		_make_building("Town Hall", Vector2i(6, 3), "town", Color("#7189aa"), 500),
		_make_building("Home", Vector2i(3, 2), "home", Color("#db5d52"), 300),
		_make_building("Home", Vector2i(7, 2), "home", Color("#db5d52"), 300),
		_make_building("Home", Vector2i(4, 4), "home", Color("#db5d52"), 300),
		_make_building("Coin Mint", Vector2i(8, 4), "mint", Color("#c89035"), 300, "intact", "coins", 12.0)
	]
	road_cells = ROAD_CELLS.duplicate()
	# A cell can hold exactly one thing. Starter buildings take priority, so
	# remove any matching road cell instead of drawing a road underneath them.
	for starter in buildings:
		for occupied_cell in _building_footprint_cells(starter):
			road_cells.erase(occupied_cell)
	resources = {"coins": 900, "energy": 0, "water": 0, "population": 12, "attack": 5}
	inventory = {"mint": 0, "power": 0, "water": 0, "home": 0, "store": 0, "defense": 0, "town": 0, "road": 0}
	selected_building = -1
	placement_item = ""
	context_open = false
	move_mode = false
	build_phase = true
	selected_card = "home"
	adviser = "Starter town ready. Buy buildings from the shop and place them from INVENTORY."

func _make_building(label: String, grid: Vector2i, kind: String, color: Color, health: int, state := "intact", produces := "", rate := 0.0, footprint := Vector2i.ONE) -> Dictionary:
	var interval := 30.0
	if kind == "power" or kind == "water":
		interval = 45.0
	if kind == "store":
		interval = 40.0
	return {"label": label, "grid": grid, "kind": kind, "footprint": footprint, "color": color, "hp": health, "max_hp": health, "state": state, "produces": produces, "rate": rate, "buffer": 0.0, "collect_timer": interval, "collect_interval": interval, "pending": 0}

func _card_list() -> Array:
	if build_phase:
		return [
			{"id":"mint", "name":"COIN MINT", "cost":100, "color":Color("#d89b34"), "stat":"+12 COINS / SEC"},
			{"id":"power", "name":"POWER PLANT", "cost":150, "color":Color("#e9c34e"), "stat":"+4 ENERGY / SEC"},
			{"id":"water", "name":"WATER WORKS", "cost":150, "color":Color("#4f9ed0"), "stat":"+4 WATER / SEC"},
			{"id":"home", "name":"HOME", "cost":200, "color":Color("#db5d52"), "stat":"+4 POPULATION"},
			{"id":"store", "name":"STORE", "cost":250, "color":Color("#9a68b5"), "stat":"+8 COINS / 40 SEC"},
			{"id":"defense", "name":"DEFENSE TOWER", "cost":300, "color":Color("#637783"), "stat":"GARRISON -2 POP"},
			{"id":"town", "name":"TOWN HALL", "cost":400, "color":Color("#7189aa"), "stat":"FOUND YOUR CITY"}
		]
	return [
		{"id":"ape", "name":"GIANT APE", "cost":450, "color":Color("#79504a"), "stat":"DAMAGE 414"},
		{"id":"bomb", "name":"BOMB", "cost":150, "color":Color("#59697c"), "stat":"BLAST AREA"},
		{"id":"home", "name":"RED ROOF HOME", "cost":300, "color":Color("#db5d52"), "stat":"POPULATION +4"}
	]

func _origin() -> Vector2:
	return Vector2(get_viewport_rect().size.x * 0.5, 155.0)

func _iso(grid: Vector2i) -> Vector2:
	var o := _origin()
	return o + Vector2((grid.x - grid.y) * TILE.x, (grid.x + grid.y) * TILE.y)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#87d169"))
	_draw_map()
	_draw_hud()
	_draw_deck()
	_draw_inventory_panel()
	_draw_context_menu()
	if tutorial:
		_draw_tutorial()
	if won:
		_draw_result(true)
	if lost:
		_draw_result(false)

func _draw_map() -> void:
	# The reference uses a clean lawn with the grid implied by roads and lots,
	# rather than a visible wireframe across every tile.
	var outline := PackedVector2Array([
		_iso(Vector2i(0, 0)) + Vector2(0, -TILE.y),
		_iso(Vector2i(0, ROWS - 1)) + Vector2(-TILE.x, 0),
		_iso(Vector2i(COLS - 1, ROWS - 1)) + Vector2(0, TILE.y),
		_iso(Vector2i(COLS - 1, 0)) + Vector2(TILE.x, 0)
	])
	draw_colored_polygon(outline, Color("#b9df79"))
	draw_polyline(PackedVector2Array([outline[0], outline[1], outline[2], outline[3], outline[0]]), Color("#75b66b"), 2.0)
	_draw_roads()
	if selected_card == "ape" and not tutorial and monster_preview_grid.x >= 0:
		for path_cell in _monster_path_cells(monster_preview_grid):
			var highlight := _tile_polygon(path_cell, Vector2(0, 1))
			draw_colored_polygon(highlight, Color(0.1, 0.85, 0.9, 0.18))
			draw_polyline(PackedVector2Array([highlight[0], highlight[1], highlight[2], highlight[3], highlight[0]]), Color(0.1, 0.85, 0.9, 0.62), 2.0)
	for b in buildings:
		_draw_building(b)
	for m in monsters:
		_draw_monster(m)
	for p in particles:
		if p.kind == "blast":
			draw_circle(p.pos, 70.0 * (1.0 - p.life), Color(1.0, 0.45, 0.1, p.life))
		else:
			draw_circle(p.pos, 15.0 * p.life, Color(1.0, 0.25, 0.12, p.life))
	for n in numbers:
		draw_string(ui_font, n.pos, str(n.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ff4e48"))

func _draw_roads() -> void:
	for cell in road_cells:
		var tile: PackedVector2Array = _tile_polygon(cell)
		# A road is a complete board cell. Adjacent road cells touch through
		# their matching diamond edges, producing streets without stray strokes.
		draw_colored_polygon(tile, Color("#77837d"))
		draw_polyline(PackedVector2Array([tile[0], tile[1], tile[2], tile[3], tile[0]]), Color("#5b6863"), 1.5)
		# Slightly inset lane keeps the cell shape readable while preserving
		# the raised road edge used by the reference game.
		var lane: PackedVector2Array = _tile_polygon(cell, Vector2(0, 1))
		draw_polyline(PackedVector2Array([lane[0], lane[1], lane[2], lane[3], lane[0]]), Color("#aab2aa"), 2.0)

func _tile_polygon(grid: Vector2i, offset := Vector2.ZERO) -> PackedVector2Array:
	var center := _iso(grid) + offset
	return PackedVector2Array([
		center + Vector2(0, -TILE.y),
		center + Vector2(TILE.x, 0),
		center + Vector2(0, TILE.y),
		center + Vector2(-TILE.x, 0)
	])

func _building_center(building: Dictionary) -> Vector2:
	var footprint: Vector2i = building.get("footprint", Vector2i.ONE)
	return _iso(building.grid) + Vector2((footprint.x - 1) * TILE.x * 0.5, (footprint.y - 1) * TILE.y * 0.5)

func _draw_building(b: Dictionary) -> void:
	var q: Vector2 = _building_center(b)
	if b.state == "destroyed":
		draw_circle(q + Vector2(0, 7), 25, Color("#5d554e"))
		draw_string(ui_font, q + Vector2(-28, 36), "RUBBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#514940"))
		return
	var chosen: bool = selected_building >= 0 and buildings[selected_building] == b
	var foundation: PackedVector2Array
	if b.kind == "store":
		# Union of two adjacent 2:1 isometric cells, viewed as one lot.
		foundation = PackedVector2Array([
			q + Vector2(-22, -33), q + Vector2(22, -11), q + Vector2(66, 11),
			q + Vector2(22, 33), q + Vector2(-22, 11), q + Vector2(-66, -11)
		])
	else:
		foundation = PackedVector2Array([q + Vector2(-31, 8), q + Vector2(0, 20), q + Vector2(31, 8), q + Vector2(0, -4)])
	draw_colored_polygon(foundation, Color("#fff0a8") if chosen else Color("#d5c49b"))
	var body: PackedVector2Array
	if b.kind == "store":
		body = PackedVector2Array([
			q + Vector2(-40, 8), q + Vector2(-40, -17), q + Vector2(0, -39),
			q + Vector2(40, -17), q + Vector2(40, 8), q + Vector2(0, 29)
		])
	else:
		body = PackedVector2Array([q + Vector2(-23, 1), q + Vector2(-23, -25), q + Vector2(0, -39), q + Vector2(23, -25), q + Vector2(23, 1), q + Vector2(0, 14)])
	var connected := _is_building_connected(b)
	draw_colored_polygon(body, Color("#7d756c") if not connected else (Color("#59494b") if b.state == "damaged" else b.color))
	if b.kind == "home":
		draw_colored_polygon(PackedVector2Array([q + Vector2(-28, -24), q + Vector2(0, -47), q + Vector2(28, -24), q + Vector2(0, -13)]), Color("#a73d43"))
		draw_rect(Rect2(q + Vector2(-5, -5), Vector2(10, 18)), Color("#654434"))
	elif b.kind == "store":
		draw_colored_polygon(PackedVector2Array([q + Vector2(-45, -18), q + Vector2(0, -46), q + Vector2(45, -18), q + Vector2(0, 5)]), Color("#744b8e"))
		draw_rect(Rect2(q + Vector2(-27, -8), Vector2(16, 12)), Color("#bce9e7"))
		draw_rect(Rect2(q + Vector2(11, -8), Vector2(16, 12)), Color("#bce9e7"))
		draw_rect(Rect2(q + Vector2(-5, 3), Vector2(10, 20)), Color("#5a3e4a"))
	else:
		draw_rect(Rect2(q + Vector2(-13, -20), Vector2(10, 10)), Color("#bce9e7"))
		draw_rect(Rect2(q + Vector2(4, -20), Vector2(10, 10)), Color("#bce9e7"))
	if b.kind == "town":
		draw_circle(q + Vector2(0, -45), 8, Color("#f6d36a"))
		draw_string(ui_font, q + Vector2(-30, 36), "TOWN HALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#334454"))
	if b.kind == "mint":
		draw_string(ui_font, q + Vector2(-20, -31), "MINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "power":
		draw_string(ui_font, q + Vector2(-24, -31), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "water":
		draw_string(ui_font, q + Vector2(-24, -31), "WATER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "store":
		draw_string(ui_font, q + Vector2(-22, -31), "STORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "gas":
		draw_rect(Rect2(q + Vector2(-17, -38), Vector2(34, 8)), Color("#ed514b"))
		draw_string(ui_font, q + Vector2(-12, -31), "GAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "shop":
		draw_string(ui_font, q + Vector2(-17, -31), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "gun":
		draw_circle(q + Vector2(0, -28), 10, Color("#354b59"))
		draw_line(q + Vector2(0, -28), q + Vector2(18, -43), Color("#26343d"), 6.0)
		draw_string(ui_font, q + Vector2(-30, -49), "DEFENSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if not connected:
		draw_circle(q + Vector2(27, -47), 7, Color("#d9534f"))
		draw_string(ui_font, q + Vector2(31, -43), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	elif b.pending > 0:
		draw_circle(q + Vector2(27, -47), 7, Color("#f2c24f"))
		draw_string(ui_font, q + Vector2(24, -43), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	if b.state == "damaged":
		draw_circle(q + Vector2(22, -47), 12, Color("#9c5bd0"))
		draw_string(ui_font, q + Vector2(18, -42), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var ratio := clampf(float(b.hp) / float(b.max_hp), 0.0, 1.0)
	draw_rect(Rect2(q + Vector2(-23, 19), Vector2(46, 4)), Color("#3d4a4b"))
	draw_rect(Rect2(q + Vector2(-23, 19), Vector2(46 * ratio, 4)), GREEN if ratio > 0.5 else Color("#e64e4b"))

func _draw_monster(m: Dictionary) -> void:
	var q: Vector2 = m.pos
	_draw_shadow_ellipse(q + Vector2(0, 12), Vector2(27, 10), Color(0.08, 0.12, 0.13, 0.3))
	draw_circle(q + Vector2(0, -20), 22, Color("#4e332b") if m.kind == "ape" else Color("#4f9a59"))
	draw_circle(q + Vector2(-16, -27), 9, Color("#684035"))
	draw_circle(q + Vector2(16, -27), 9, Color("#684035"))
	draw_circle(q + Vector2(-7, -23), 3, Color("#f6dd8d"))
	draw_circle(q + Vector2(7, -23), 3, Color("#f6dd8d"))
	draw_line(q + Vector2(-10, -5), q + Vector2(-18, 12), Color("#4e332b"), 8.0)
	draw_line(q + Vector2(10, -5), q + Vector2(18, 12), Color("#4e332b"), 8.0)

func _draw_hud() -> void:
	var w := get_viewport_rect().size.x
	draw_rect(Rect2(0, 0, w, 86), Color("#f6e8c2"))
	draw_rect(Rect2(0, 82, w, 4), ORANGE)
	draw_string(ui_font, Vector2(24, 35), "MONSTERMIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, NAVY)
	draw_string(ui_font, Vector2(25, 59), "BLOWTOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#709073"))
	var stat_x := maxf(285.0, w - 590.0)
	_draw_resource_stat(Vector2(stat_x, 14), "CURRENCY", resources.coins, "COINS", Color("#b77c20"))
	_draw_resource_stat(Vector2(stat_x + 120, 14), "POPULATION", resources.population, "RESIDENTS", Color("#65a46c"))
	_draw_resource_stat(Vector2(stat_x + 240, 14), "ENERGY", resources.energy, "POWER", Color("#d89d32"))
	_draw_resource_stat(Vector2(stat_x + 360, 14), "WATER", resources.water, "SUPPLY", Color("#4f85dc"))
	draw_string(ui_font, Vector2(24, 120), "CITY 01  •  BUILD YOUR CITY" if build_phase else "CITY 01  •  DESTROY THE TOWN HALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NAVY)
	if not build_phase:
		draw_string(ui_font, Vector2(w - 220, 120), "TIME  %03d" % int(mission_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a44236"))

func _draw_resource_stat(position: Vector2, label: String, value: int, suffix: String, color: Color) -> void:
	draw_rect(Rect2(position, Vector2(108, 56)), Color("#fff8e7"))
	draw_string(ui_font, position + Vector2(8, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#6f7f76"))
	draw_string(ui_font, position + Vector2(8, 39), "%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	draw_string(ui_font, position + Vector2(52, 38), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#6f7f76"))

func _draw_deck() -> void:
	var w := get_viewport_rect().size.x
	draw_rect(Rect2(0, HUD_BOTTOM, w, get_viewport_rect().size.y - HUD_BOTTOM), Color("#e9dcc0"))
	draw_string(ui_font, Vector2(22, HUD_BOTTOM + 25), "BUILDING SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#6f7f76"))
	var inventory_button := Rect2(20, HUD_BOTTOM + 38, 170, 54)
	draw_rect(inventory_button, Color("#fff8e7") if inventory_open else Color("#d4c5a9"))
	draw_rect(inventory_button, BLUE if inventory_open else Color("#a99980"), false, 3.0)
	draw_string(ui_font, inventory_button.position + Vector2(14, 23), "INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, NAVY)
	draw_string(ui_font, inventory_button.position + Vector2(14, 42), "stored buildings: %d" % _inventory_total(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#6a756d"))
	var cards := _card_list()
	var card_width := minf(176.0, (w - 245.0) / float(cards.size()))
	for i in cards.size():
		var card: Dictionary = cards[i]
		var rect := Rect2(210 + i * card_width, HUD_BOTTOM + 2, card_width - 8, 108)
		draw_rect(rect, Color("#fff8e7") if selected_card == card.id else Color("#d4c5a9"))
		draw_rect(rect, BLUE if selected_card == card.id else Color("#a99980"), false, 3.0)
		draw_circle(rect.position + Vector2(23, 34), 18, card.color)
		draw_string(ui_font, rect.position + Vector2(46, 25), card.name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 52, 10, NAVY)
		draw_string(ui_font, rect.position + Vector2(46, 45), card.stat, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 52, 8, Color("#6a756d"))
		draw_rect(Rect2(rect.position + Vector2(46, 62), Vector2(54, 23)), Color("#efd36b"))
		draw_string(ui_font, rect.position + Vector2(55, 79), "%d C" % card.cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#614b26"))
	if build_phase:
		draw_rect(Rect2(w - 200, HUD_BOTTOM + 15, 120, 76), Color("#52a66a"))
		draw_string(ui_font, Vector2(w - 193, HUD_BOTTOM + 46), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_string(ui_font, Vector2(w - 180, HUD_BOTTOM + 68), "ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e8ffdf"))
	else:
		draw_rect(Rect2(w - 200, HUD_BOTTOM + 15, 120, 76), Color("#d8544d"))
		draw_string(ui_font, Vector2(w - 193, HUD_BOTTOM + 46), "END", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		draw_string(ui_font, Vector2(w - 184, HUD_BOTTOM + 68), "ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffe6bf"))

func _draw_inventory_panel() -> void:
	if not inventory_open:
		return
	var panel := Rect2(get_viewport_rect().size.x - 326, 142, 306, 431)
	draw_rect(panel, Color("#fff7dd"))
	draw_rect(panel, Color("#a99980"), false, 3.0)
	draw_string(ui_font, panel.position + Vector2(18, 28), "CITY INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, NAVY)
	draw_string(ui_font, panel.position + Vector2(18, 48), "Buy now, place later", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#6a756d"))
	var entries: Array[Dictionary] = [
		{"id":"home", "name":"HOME"}, {"id":"mint", "name":"COIN MINT"},
		{"id":"power", "name":"POWER PLANT"}, {"id":"water", "name":"WATER WORKS"},
		{"id":"store", "name":"STORE (2 X 1)"}, {"id":"defense", "name":"DEFENSE TOWER"},
		{"id":"road", "name":"ROAD CELL"}, {"id":"town", "name":"TOWN HALL"}
	]
	var row := 0
	for entry in entries:
		var count: int = inventory[entry.id]
		var row_rect := Rect2(panel.position + Vector2(14, 58 + row * 43), Vector2(278, 35))
		draw_rect(row_rect, Color("#e9dcc0") if count > 0 else Color("#f4ecd9"))
		draw_string(ui_font, row_rect.position + Vector2(10, 23), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, NAVY)
		draw_string(ui_font, row_rect.position + Vector2(218, 23), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#526168"))
		row += 1

func _draw_context_menu() -> void:
	if not context_open:
		return
	var panel_pos := context_position
	panel_pos.x = clampf(panel_pos.x, 8.0, get_viewport_rect().size.x - 194.0)
	panel_pos.y = clampf(panel_pos.y, 92.0, HUD_BOTTOM - 122.0)
	var panel := Rect2(panel_pos, Vector2(186, 112))
	draw_rect(panel, Color("#fff7dd"))
	draw_rect(panel, ORANGE, false, 2.0)
	var label := "ROAD CELL"
	if context_type == "building" and context_building >= 0:
		label = buildings[context_building].label
	draw_string(ui_font, panel.position + Vector2(12, 23), label, HORIZONTAL_ALIGNMENT_LEFT, 162, 13, NAVY)
	draw_rect(Rect2(panel.position + Vector2(10, 34), Vector2(78, 33)), Color("#52a66a"))
	draw_string(ui_font, panel.position + Vector2(25, 56), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_rect(Rect2(panel.position + Vector2(98, 34), Vector2(78, 33)), Color("#7189aa"))
	draw_string(ui_font, panel.position + Vector2(108, 56), "STORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ui_font, panel.position + Vector2(12, 94), "Click the $ icon to collect", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#6a756d"))

func _draw_adviser() -> void:
	var h := get_viewport_rect().size.y
	draw_circle(Vector2(72, h - 87), 36, Color("#364c5d"))
	draw_circle(Vector2(72, h - 97), 20, Color("#e4a67b"))
	draw_string(ui_font, Vector2(59, h - 90), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_rect(Rect2(112, h - 132, 430, 67), Color("#fffdf0"))
	draw_string(ui_font, Vector2(130, h - 105), adviser, HORIZONTAL_ALIGNMENT_LEFT, 395, 14, NAVY)

func _draw_tutorial() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.12, 0.15, 0.3))
	var p := Rect2(size.x * 0.5 - 245, 176, 490, 248)
	draw_rect(p, Color("#fff7dd"))
	draw_rect(Rect2(p.position, Vector2(p.size.x, 44)), ORANGE)
	draw_string(ui_font, p.position + Vector2(22, 30), "MONSTERMIND ADVISER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ui_font, p.position + Vector2(28, 83), "BUILD YOUR CITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, NAVY)
	draw_string(ui_font, p.position + Vector2(28, 119), "Start with a Coin Mint, Power Plant, and Water Works.", HORIZONTAL_ALIGNMENT_LEFT, 425, 15, Color("#526168"))
	draw_string(ui_font, p.position + Vector2(28, 151), "Roads must connect every building back to the Town Hall.", HORIZONTAL_ALIGNMENT_LEFT, 425, 13, Color("#526168"))
	draw_rect(Rect2(p.position + Vector2(330, 185), Vector2(130, 42)), GREEN)
	draw_string(ui_font, p.position + Vector2(362, 212), "NICE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _draw_result(success: bool) -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.12, 0.55))
	var p := Rect2(size.x * 0.5 - 300, 160, 600, 360)
	draw_rect(p, Color("#fff7dd"))
	draw_rect(Rect2(p.position, Vector2(p.size.x, 58)), ORANGE if success else Color("#b84d42"))
	draw_string(ui_font, p.position + Vector2(178, 39), "CITY COMPLETE!" if success else "CITY OVERRUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(ui_font, p.position + Vector2(45, 120), "TOTAL SCORE     %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, NAVY)
	draw_string(ui_font, p.position + Vector2(45, 170), "★  ★  ★" if success else "Try a different attack plan.", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#f3b845") if success else NAVY)
	draw_string(ui_font, p.position + Vector2(45, 220), "REWARDS   ◆ 50     ● 1000" if success else "The timer ran out.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, NAVY)
	draw_rect(_retry_rect(), GREEN)
	draw_string(ui_font, p.position + Vector2(265, 304), "RETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _retry_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(Vector2(size.x * 0.5 - 80.0, 435.0), Vector2(160, 45))

func _update_monsters(delta: float) -> void:
	for i in range(monsters.size() - 1, -1, -1):
		var m: Dictionary = monsters[i]
		m.cooldown -= delta
		if m.moving:
			m.move_progress += delta / 0.42
			m.pos = m.from_pos.lerp(m.to_pos, minf(m.move_progress, 1.0))
			if m.move_progress >= 1.0:
				m.grid = m.to_grid
				m.pos = _iso(m.grid)
				m.moving = false
			continue
		var target := _building_at_cell(m.grid)
		if target >= 0 and buildings[target].state != "destroyed":
			m.target = target
			if m.cooldown <= 0.0:
				m.cooldown = 1.05
				_damage(target, 414)
			continue
		var next_grid: Vector2i = m.grid + m.direction
		if next_grid.x < 0 or next_grid.x >= COLS or next_grid.y < 0 or next_grid.y >= ROWS:
			monsters.remove_at(i)
			continue
		# Roads are traversable. Buildings are checked on the next cell and
		# become the monster's target instead of being selected by proximity.
		m.from_pos = _iso(m.grid)
		m.to_pos = _iso(next_grid)
		m.to_grid = next_grid
		m.move_progress = 0.0
		m.moving = true

func _building_at_cell(grid: Vector2i) -> int:
	for i in buildings.size():
		if buildings[i].state != "destroyed" and grid in _building_footprint_cells(buildings[i]):
			return i
	return -1

func _attack_direction(start_grid: Vector2i) -> Vector2i:
	var town_grid := start_grid
	for b in buildings:
		if b.kind == "town" and b.state != "destroyed":
			town_grid = b.grid
			break
	var difference: Vector2i = town_grid - start_grid
	if abs(difference.x) >= abs(difference.y) and difference.x != 0:
		return Vector2i(1 if difference.x > 0 else -1, 0)
	if difference.y != 0:
		return Vector2i(0, 1 if difference.y > 0 else -1)
	return Vector2i(1, 0)

func _monster_path_cells(start_grid: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if start_grid.x < 0:
		return path
	var direction := _attack_direction(start_grid)
	var cell := start_grid
	# The attack lane always begins at the outside edge of the board. The
	# hovered cell only chooses which row or column the monster will enter on.
	if direction.x != 0:
		cell = Vector2i(0 if direction.x > 0 else COLS - 1, start_grid.y)
	else:
		cell = Vector2i(start_grid.x, 0 if direction.y > 0 else ROWS - 1)
	while cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS:
		path.append(cell)
		cell += direction
	return path

func _road_cells_connected_to_town() -> Dictionary:
	var result := {}
	var town_grid := Vector2i(-1, -1)
	for b in buildings:
		if b.kind == "town" and b.state != "destroyed":
			town_grid = b.grid
			break
	if town_grid.x < 0:
		return result
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var queue: Array[Vector2i] = []
	for direction in directions:
		var next_cell: Vector2i = town_grid + direction
		if next_cell in road_cells and not result.has(next_cell):
			result[next_cell] = true
			queue.append(next_cell)
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction in directions:
			var next_cell: Vector2i = current + direction
			if next_cell in road_cells and not result.has(next_cell):
				result[next_cell] = true
				queue.append(next_cell)
	return result

func _is_building_connected(building: Dictionary) -> bool:
	if building.kind == "town":
		return true
	var connected_roads := _road_cells_connected_to_town()
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for footprint_cell in _building_footprint_cells(building):
		for direction in directions:
			if connected_roads.has(footprint_cell + direction):
				return true
	return false

func _worker_cost(kind: String) -> int:
	if kind == "gun":
		return 2
	if ["mint", "power", "water", "store", "gas", "shop"].has(kind):
		return 1
	return 0

func _update_production(delta: float) -> void:
	for b in buildings:
		if b.state != "intact" or b.produces == "" or not _is_building_connected(b):
			continue
		b.collect_timer -= delta
		if b.collect_timer <= 0.0:
			b.pending += int(b.rate)
			b.collect_timer += b.collect_interval
	# Homes add residents, while connected businesses and defenses require
	# residents to work and guard them. Disconnected buildings do nothing.
	resources.population = 0
	for b in buildings:
		if b.state != "intact" or not _is_building_connected(b):
			continue
		if b.kind == "home":
			resources.population += 4
		resources.population -= _worker_cost(b.kind)
	resources.population = maxi(0, resources.population)

func _collect_context_target() -> void:
	if context_type != "building" or context_building < 0 or context_building >= buildings.size():
		adviser = "Only business buildings have payouts to collect."
		return
	var building: Dictionary = buildings[context_building]
	if not _is_building_connected(building):
		adviser = "%s is offline. Connect its road to the Town Hall first." % building.label
		return
	var amount: int = int(building.pending)
	if amount <= 0:
		adviser = "%s has no payout ready yet. Check back after its timer." % building.label
		return
	resources[building.produces] += amount
	building.pending = 0
	numbers.append({"pos": _iso(building.grid) + Vector2(-15, -55), "value": amount, "life": 0.8})
	adviser = "Collected %d %s from %s." % [amount, building.produces.to_upper(), building.label]

func _grid_from_mouse(mouse: Vector2) -> Vector2i:
	var local := mouse - _origin()
	var projected_x := local.x / TILE.x
	var projected_y := local.y / TILE.y
	var candidate := Vector2i(round((projected_x + projected_y) * 0.5), round((projected_y - projected_x) * 0.5))
	if candidate.x < 0 or candidate.x >= COLS or candidate.y < 0 or candidate.y >= ROWS:
		return Vector2i(-1, -1)
	var tile := _tile_polygon(candidate)
	return candidate if Geometry2D.is_point_in_polygon(mouse, tile) else Vector2i(-1, -1)

func _occupied(grid: Vector2i) -> bool:
	if grid in road_cells:
		return true
	return _occupied_by_building(grid)

func _building_footprint_cells(building: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var footprint: Vector2i = building.get("footprint", Vector2i.ONE)
	for y in footprint.y:
		for x in footprint.x:
			cells.append(building.grid + Vector2i(x, y))
	return cells

func _building_area_occupied(grid: Vector2i, footprint: Vector2i, ignore_index := -1) -> bool:
	for y in footprint.y:
		for x in footprint.x:
			var cell := grid + Vector2i(x, y)
			if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS or cell in road_cells:
				return true
			for i in buildings.size():
				if i == ignore_index:
					continue
				if cell in _building_footprint_cells(buildings[i]) and buildings[i].state != "destroyed":
					return true
	return false

func _occupied_by_building(grid: Vector2i) -> bool:
	for b in buildings:
		if grid in _building_footprint_cells(b) and b.state != "destroyed":
			return true
	return false

func _building_catalog() -> Dictionary:
	return {
		"mint": {"label":"Coin Mint", "kind":"mint", "color":Color("#c89035"), "cost":100, "produces":"coins", "rate":12.0},
		"power": {"label":"Power Plant", "kind":"power", "color":Color("#d6a83d"), "cost":150, "produces":"energy", "rate":4.0},
		"water": {"label":"Water Works", "kind":"water", "color":Color("#4f9ed0"), "cost":150, "produces":"water", "rate":4.0},
		"home": {"label":"Home", "kind":"home", "color":Color("#db5d52"), "cost":200, "produces":"", "rate":0.0},
		"store": {"label":"Store", "kind":"store", "color":Color("#9a68b5"), "cost":250, "produces":"coins", "rate":8.0, "footprint":Vector2i(2, 1)},
		"defense": {"label":"Defense Tower", "kind":"gun", "color":Color("#637783"), "cost":300, "produces":"", "rate":0.0},
		"town": {"label":"Town Hall", "kind":"town", "color":Color("#7189aa"), "cost":400, "produces":"", "rate":0.0}
	}

func _inventory_total() -> int:
	var total := 0
	for key in inventory:
		total += int(inventory[key])
	return total

func _has_town_hall_anywhere() -> bool:
	if inventory["town"] > 0:
		return true
	for b in buildings:
		if b.kind == "town" and b.state != "destroyed":
			return true
	return false

func _buy_building_to_inventory(id: String) -> void:
	var data := _building_catalog()
	if not data.has(id):
		return
	if id == "town" and _has_town_hall_anywhere():
		adviser = "Only one Town Hall is allowed in the city."
		return
	var info: Dictionary = data[id]
	if resources.coins < info.cost:
		adviser = "You need %d coins to buy the %s." % [info.cost, info.label]
		return
	resources.coins -= info.cost
	inventory[id] += 1
	inventory_open = true
	placement_item = ""
	adviser = "%s bought. Open INVENTORY and select it when you are ready to place it." % info.label

func _place_road(grid: Vector2i) -> void:
	if grid in road_cells:
		adviser = "There is already a road cell there."
		return
	if _occupied(grid):
		adviser = "That space is occupied. Choose an empty tile."
		return
	road_cells.append(grid)
	inventory["road"] -= 1
	placement_item = ""
	adviser = "Road cell placed. Select it to move or store it later."

func _place_building(id: String, grid: Vector2i, from_inventory := false) -> void:
	var data := _building_catalog()
	if not data.has(id):
		return
	var info: Dictionary = data[id]
	if id == "town" and _has_town_hall_anywhere():
		adviser = "Only one Town Hall is allowed in the city."
		return
	var footprint: Vector2i = info.get("footprint", Vector2i.ONE)
	if _building_area_occupied(grid, footprint):
		adviser = "That space is occupied. Choose an empty tile."
		return
	if not from_inventory and resources.coins < info.cost:
		adviser = "You need %d coins to build the %s." % [info.cost, info.label]
		return
	if from_inventory:
		if inventory[id] <= 0:
			adviser = "That item is no longer in your inventory."
			return
		inventory[id] -= 1
	else:
		resources.coins -= info.cost
	buildings.append(_make_building(info.label, grid, info.kind, info.color, 500 if id == "town" else 300, "intact", info.produces, info.rate, footprint))
	placement_item = ""
	if id == "town":
		adviser = "Town Hall placed. Your city can only have one. Keep building your starter town."
	elif id == "home":
		adviser = "Home added 4 residents. Choose another building from the shop."
	else:
		adviser = "%s is producing %s. Build the other resource buildings next." % [info.label, info.produces.to_upper()]

func _nearest_target(pos: Vector2) -> int:
	var result := -1
	var nearest := INF
	for i in buildings.size():
		if buildings[i].state == "destroyed" or buildings[i].kind == "gun":
			continue
		var distance: float = pos.distance_to(_building_center(buildings[i]))
		if distance < nearest:
			nearest = distance
			result = i
	return result

func _damage(index: int, amount: int) -> void:
	if index < 0 or buildings[index].state == "destroyed":
		return
	var b: Dictionary = buildings[index]
	b.hp -= amount
	b.state = "burning" if b.hp < b.max_hp * 0.65 else "intact"
	numbers.append({"pos": _building_center(b) + Vector2(-15, -55), "value": amount, "life": 0.8})
	particles.append({"pos": _building_center(b) + Vector2(0, -25), "life": 0.35, "kind": "hit"})
	score += amount
	if b.hp <= 0:
		b.hp = 0
		b.state = "destroyed"
		score += 1000
		if b.kind == "town":
			won = true
			adviser = "A perfect hit! The city is complete."

func _update_visuals(delta: float) -> void:
	for p in particles:
		p.life -= delta
	for n in numbers:
		n.life -= delta
		n.pos.y -= delta * 20.0
	particles = particles.filter(func(p): return p.life > 0.0)
	numbers = numbers.filter(func(n): return n.life > 0.0)

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if selected_card == "ape" and not tutorial and not build_phase:
			monster_preview_grid = _grid_from_mouse(event.position)
			queue_redraw()
		return
	if event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse: Vector2 = event.position
	if won or lost:
		if _retry_rect().has_point(mouse):
			_make_city()
			monsters.clear()
			score = 0
			mission_time = 180.0
			won = false
			lost = false
			tutorial = true
			adviser = "Starter town ready. Buy buildings from the shop and place them from INVENTORY."
		return
	if tutorial:
		var tutorial_button := Rect2(Vector2(get_viewport_rect().size.x * 0.5 + 85.0, 361.0), Vector2(130, 42))
		if tutorial_button.has_point(mouse):
			tutorial = false
			adviser = "Buy a building from the shop, then place it from INVENTORY when ready."
		return
	if context_open:
		var menu_pos := context_position
		menu_pos.x = clampf(menu_pos.x, 8.0, get_viewport_rect().size.x - 194.0)
		menu_pos.y = clampf(menu_pos.y, 92.0, HUD_BOTTOM - 122.0)
		if Rect2(menu_pos + Vector2(10, 34), Vector2(78, 33)).has_point(mouse):
			move_mode = true
			context_open = false
			adviser = "Choose an empty tile to move the selected %s." % ("road cell" if context_type == "road" else "building")
			return
		if Rect2(menu_pos + Vector2(98, 34), Vector2(78, 33)).has_point(mouse):
			_store_context_target()
			context_open = false
			return
		context_open = false
		return
	if inventory_open:
		var panel := Rect2(get_viewport_rect().size.x - 326, 142, 306, 431)
		if Rect2(20, HUD_BOTTOM + 38, 170, 54).has_point(mouse):
			inventory_open = false
			return
		var entries: Array[String] = ["home", "mint", "power", "water", "store", "defense", "road", "town"]
		for row in entries.size():
			var row_rect := Rect2(panel.position + Vector2(14, 58 + row * 43), Vector2(278, 35))
			if row_rect.has_point(mouse):
				if inventory[entries[row]] > 0:
					placement_item = entries[row]
					inventory_open = false
					adviser = "Selected %s from inventory. Click an empty city cell to place it." % entries[row].to_upper()
				else:
					adviser = "That inventory slot is empty. Buy one from the shop first."
				return
		inventory_open = false
		return
	if Rect2(20, HUD_BOTTOM + 38, 170, 54).has_point(mouse):
		inventory_open = not inventory_open
		return
	if not build_phase and Rect2(get_viewport_rect().size.x - 200, HUD_BOTTOM + 15, 120, 76).has_point(mouse):
		build_phase = true
		monsters.clear()
		selected_card = "home"
		monster_preview_grid = Vector2i(-1, -1)
		adviser = "Attack ended. Build defenses and expand your city."
		return
	if build_phase and Rect2(get_viewport_rect().size.x - 200, HUD_BOTTOM + 15, 120, 76).has_point(mouse):
		if _has_town_hall_anywhere():
			build_phase = false
			mission_time = 180.0
			selected_card = "ape"
			monster_preview_grid = Vector2i(-1, -1)
			adviser = "City ready! Select GIANT APE or BOMB to attack the next city."
		else:
			adviser = "Place a Town Hall before starting the attack phase."
		return
	var cards := _card_list()
	var card_width := minf(176.0, (get_viewport_rect().size.x - 245.0) / float(cards.size()))
	for i in cards.size():
		if Rect2(210 + i * card_width, HUD_BOTTOM + 2, card_width - 8, 108).has_point(mouse):
			selected_card = cards[i].id
			if selected_card == "ape":
				monster_preview_grid = _grid_from_mouse(mouse)
			else:
				monster_preview_grid = Vector2i(-1, -1)
			if build_phase:
				_buy_building_to_inventory(selected_card)
			return
	if move_mode:
		var move_grid := _grid_from_mouse(mouse)
		if move_grid.x < 0:
			adviser = "Click inside the city grid to move the selected item."
			return
		if context_type == "road":
			if move_grid in road_cells or _occupied_by_building(move_grid):
				adviser = "That space is occupied. Choose an empty tile."
				return
			road_cells.erase(context_road)
			road_cells.append(move_grid)
		else:
			if context_building < 0 or context_building >= buildings.size() or _building_area_occupied(move_grid, buildings[context_building].get("footprint", Vector2i.ONE), context_building):
				adviser = "That space is occupied. Choose an empty tile."
				return
			buildings[context_building].grid = move_grid
		move_mode = false
		context_type = ""
		context_road = Vector2i(-1, -1)
		context_building = -1
		adviser = "Item moved."
		return
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		var collect_icon := _building_center(b) + Vector2(27, -47)
		if b.pending > 0 and collect_icon.distance_to(mouse) <= 14.0:
			context_type = "building"
			context_building = i
			_collect_context_target()
			return
		if _building_center(b).distance_to(mouse) < 42.0 and b.state != "destroyed":
			selected_building = i
			_open_building_context(i, mouse)
			if b.state == "damaged" and resources.coins >= 120:
				resources.coins -= 120
				b.state = "intact"
				b.hp = b.max_hp
				adviser = "Building repaired! Defense is critical."
			return
	var clicked_grid := _grid_from_mouse(mouse)
	if clicked_grid in road_cells:
		_open_road_context(clicked_grid, mouse)
		return
	if mouse.y >= HUD_BOTTOM:
		return
	if placement_item != "":
		if clicked_grid.x < 0:
			adviser = "Click inside the city grid to place your building."
		elif placement_item == "road":
			_place_road(clicked_grid)
		else:
			_place_building(placement_item, clicked_grid, true)
		return
	if selected_card == "ape" and resources.attack > 0:
		resources.attack -= 1
		var attack_grid := _grid_from_mouse(mouse)
		if attack_grid.x < 0:
			adviser = "Deploy the Giant Ape on a city grid cell."
			resources.attack += 1
			return
		var attack_direction := _attack_direction(attack_grid)
		var entry_grid := attack_grid - attack_direction
		monsters.append({"kind": "ape", "grid": entry_grid, "direction": attack_direction, "pos": _iso(entry_grid), "from_pos": _iso(entry_grid), "to_pos": _iso(entry_grid), "to_grid": entry_grid, "target": -1, "cooldown": 0.3, "move_progress": 1.0, "moving": false})
		adviser = "Giant Ape enters from outside the map and advances in a straight grid line."
	elif selected_card == "bomb" and resources.coins >= 150:
		resources.coins -= 150
		for i in buildings.size():
			if _building_center(buildings[i]).distance_to(mouse) < 80.0:
				_damage(i, 260)
		particles.append({"pos": mouse, "life": 0.6, "kind": "blast"})
		adviser = "Bomb dropped. Anything in the blast radius takes damage!"

func _open_building_context(index: int, mouse: Vector2) -> void:
	context_open = true
	context_type = "building"
	context_building = index
	context_road = Vector2i(-1, -1)
	context_position = mouse + Vector2(14, -20)

func _open_road_context(cell: Vector2i, mouse: Vector2) -> void:
	context_open = true
	context_type = "road"
	context_building = -1
	context_road = cell
	context_position = mouse + Vector2(14, -20)

func _store_context_target() -> void:
	if context_type == "road":
		if context_road in road_cells:
			road_cells.erase(context_road)
			inventory["road"] += 1
			adviser = "Road cell moved to inventory."
	else:
		if context_building < 0 or context_building >= buildings.size():
			return
		var b: Dictionary = buildings[context_building]
		var item_id: String = str(b.kind)
		if inventory.has(item_id):
			inventory[item_id] += 1
			buildings.remove_at(context_building)
			selected_building = -1
			adviser = "%s moved to inventory." % b.label
	context_type = ""
	context_building = -1
	context_road = Vector2i(-1, -1)

func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
