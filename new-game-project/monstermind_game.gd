extends Node2D

## MonsterMind Reborn prototype.
## This is intentionally a single new file: it does not alter the starter
## scene or project settings. Attach it to a Node2D to run the prototype.

const TILE := Vector2(44.0, 23.0)
const COLS := 12
const ROWS := 8
const HUD_BOTTOM := 585.0
const NAVY := Color("#193b5a")
const BLUE := Color("#19b8d0")
const ORANGE := Color("#f28c38")
const GREEN := Color("#52c86b")

var ui_font: Font
var buildings: Array = []
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
var adviser := "Start your city by building a Coin Mint, Power Plant, and Water Works."

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	_make_city()
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if not tutorial and not won and not lost:
		_update_production(delta)
		if not build_phase:
			mission_time = maxf(0.0, mission_time - delta)
		_update_monsters(delta)
		if not build_phase and mission_time == 0.0:
			lost = true
	_update_visuals(delta)
	queue_redraw()

func _make_city() -> void:
	# The opening map is intentionally empty. The player establishes every
	# production chain instead of inheriting a pre-built town.
	buildings = []
	resources = {"coins": 900, "energy": 0, "water": 0, "population": 0, "attack": 5}
	build_phase = true
	selected_card = "mint"

func _make_building(label: String, grid: Vector2i, kind: String, color: Color, health: int, state := "intact", produces := "", rate := 0.0) -> Dictionary:
	return {"label": label, "grid": grid, "kind": kind, "color": color, "hp": health, "max_hp": health, "state": state, "produces": produces, "rate": rate, "buffer": 0.0}

func _card_list() -> Array:
	if build_phase:
		return [
			{"id":"mint", "name":"COIN MINT", "cost":100, "color":Color("#d89b34"), "stat":"+12 COINS / SEC"},
			{"id":"power", "name":"POWER PLANT", "cost":150, "color":Color("#e9c34e"), "stat":"+4 ENERGY / SEC"},
			{"id":"water", "name":"WATER WORKS", "cost":150, "color":Color("#4f9ed0"), "stat":"+4 WATER / SEC"},
			{"id":"town", "name":"TOWN HALL", "cost":400, "color":Color("#7189aa"), "stat":"FOUND YOUR CITY"}
		]
	return [
		{"id":"ape", "name":"GIANT APE", "cost":450, "color":Color("#79504a"), "stat":"DAMAGE 414"},
		{"id":"bomb", "name":"BOMB", "cost":150, "color":Color("#59697c"), "stat":"BLAST AREA"},
		{"id":"gun", "name":"MACHINE GUN NEST", "cost":650, "color":Color("#637783"), "stat":"HEALTH 300"},
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
	_draw_adviser()
	if tutorial:
		_draw_tutorial()
	if won:
		_draw_result(true)
	if lost:
		_draw_result(false)

func _draw_map() -> void:
	var o := _origin()
	var outline := PackedVector2Array([o + Vector2(-COLS * TILE.x, 0), o + Vector2(0, ROWS * TILE.y), o + Vector2(COLS * TILE.x, 0), o + Vector2(0, -ROWS * TILE.y)])
	draw_colored_polygon(outline, Color("#b9df79"))
	draw_polyline(PackedVector2Array([outline[0], outline[1], outline[2], outline[3], outline[0]]), Color("#5eaa5b"), 3.0)
	for x in range(COLS + 1):
		draw_line(_iso(Vector2i(x, 0)), _iso(Vector2i(x, ROWS)), Color("#a7cb75"), 1.0)
	for y in range(ROWS + 1):
		draw_line(_iso(Vector2i(0, y)), _iso(Vector2i(COLS, y)), Color("#a7cb75"), 1.0)
	for x in [3, 6, 9]:
		_draw_road(_iso(Vector2i(x, 0)), _iso(Vector2i(x, ROWS)))
	for y in [2, 5]:
		_draw_road(_iso(Vector2i(0, y)), _iso(Vector2i(COLS, y)))
	if selected_card == "ape" and not tutorial:
		for y in ROWS:
			draw_line(_iso(Vector2i(0, y)) + Vector2(0, 4), _iso(Vector2i(COLS, y)) + Vector2(0, 4), Color(0.1, 0.85, 0.9, 0.26), 9.0)
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

func _draw_road(a: Vector2, b: Vector2) -> void:
	draw_line(a + Vector2(0, 7), b + Vector2(0, 7), Color("#646e6d"), 17.0)
	draw_line(a + Vector2(0, 5), b + Vector2(0, 5), Color("#929c98"), 13.0)

func _draw_building(b: Dictionary) -> void:
	var q: Vector2 = _iso(b.grid)
	if b.state == "destroyed":
		draw_circle(q + Vector2(0, 7), 25, Color("#5d554e"))
		draw_string(ui_font, q + Vector2(-28, 36), "RUBBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#514940"))
		return
	var chosen: bool = selected_building >= 0 and buildings[selected_building] == b
	var foundation := PackedVector2Array([q + Vector2(-31, 8), q + Vector2(0, 20), q + Vector2(31, 8), q + Vector2(0, -4)])
	draw_colored_polygon(foundation, Color("#fff0a8") if chosen else Color("#d5c49b"))
	var body := PackedVector2Array([q + Vector2(-23, 1), q + Vector2(-23, -25), q + Vector2(0, -39), q + Vector2(23, -25), q + Vector2(23, 1), q + Vector2(0, 14)])
	draw_colored_polygon(body, Color("#59494b") if b.state == "damaged" else b.color)
	if b.kind == "home":
		draw_colored_polygon(PackedVector2Array([q + Vector2(-28, -24), q + Vector2(0, -47), q + Vector2(28, -24), q + Vector2(0, -13)]), Color("#a73d43"))
		draw_rect(Rect2(q + Vector2(-5, -5), Vector2(10, 18)), Color("#654434"))
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
	if b.kind == "gas":
		draw_rect(Rect2(q + Vector2(-17, -38), Vector2(34, 8)), Color("#ed514b"))
		draw_string(ui_font, q + Vector2(-12, -31), "GAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "shop":
		draw_string(ui_font, q + Vector2(-17, -31), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	if b.kind == "gun":
		draw_circle(q + Vector2(0, -28), 10, Color("#354b59"))
		draw_line(q + Vector2(0, -28), q + Vector2(18, -43), Color("#26343d"), 6.0)
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
	draw_string(ui_font, Vector2(w - 590, 39), "●  %d" % resources.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#b77c20"))
	draw_string(ui_font, Vector2(w - 470, 39), "⚡  %d" % resources.energy, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d89d32"))
	draw_string(ui_font, Vector2(w - 350, 39), "💧  %d" % resources.water, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4f85dc"))
	draw_string(ui_font, Vector2(w - 230, 39), "♟  %d" % resources.population, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#65a46c"))
	draw_circle(Vector2(w - 55, 32), 17, Color("#62c878"))
	draw_string(ui_font, Vector2(w - 63, 39), "⚙", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(ui_font, Vector2(24, 120), "CITY 01  •  BUILD YOUR CITY" if build_phase else "CITY 01  •  DESTROY THE TOWN HALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NAVY)
	if not build_phase:
		draw_string(ui_font, Vector2(w - 220, 120), "TIME  %03d" % int(mission_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a44236"))

func _draw_deck() -> void:
	var w := get_viewport_rect().size.x
	draw_rect(Rect2(0, HUD_BOTTOM, w, get_viewport_rect().size.y - HUD_BOTTOM), Color("#e9dcc0"))
	draw_string(ui_font, Vector2(22, HUD_BOTTOM + 25), "CITY ACTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#6f7f76"))
	var cards := _card_list()
	for i in cards.size():
		var card: Dictionary = cards[i]
		var rect := Rect2(250 + i * 190, HUD_BOTTOM + 2, 176, 108)
		draw_rect(rect, Color("#fff8e7") if selected_card == card.id else Color("#d4c5a9"))
		draw_rect(rect, BLUE if selected_card == card.id else Color("#a99980"), false, 3.0)
		draw_circle(rect.position + Vector2(31, 34), 22, card.color)
		draw_string(ui_font, rect.position + Vector2(60, 27), card.name, HORIZONTAL_ALIGNMENT_LEFT, 108, 12, NAVY)
		draw_string(ui_font, rect.position + Vector2(60, 49), card.stat, HORIZONTAL_ALIGNMENT_LEFT, 108, 10, Color("#6a756d"))
		draw_rect(Rect2(rect.position + Vector2(60, 63), Vector2(54, 23)), Color("#efd36b"))
		draw_string(ui_font, rect.position + Vector2(68, 80), str(card.cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#614b26"))
	if build_phase:
		draw_rect(Rect2(w - 200, HUD_BOTTOM + 15, 120, 76), Color("#52a66a"))
		draw_string(ui_font, Vector2(w - 183, HUD_BOTTOM + 46), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		draw_string(ui_font, Vector2(w - 180, HUD_BOTTOM + 68), "CITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e8ffdf"))
	else:
		draw_rect(Rect2(w - 200, HUD_BOTTOM + 15, 120, 76), Color("#d8544d"))
		draw_string(ui_font, Vector2(w - 183, HUD_BOTTOM + 46), "ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		draw_string(ui_font, Vector2(w - 180, HUD_BOTTOM + 68), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffe6bf"))

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
	draw_string(ui_font, p.position + Vector2(28, 151), "Each building generates a resource over time. Build a Town Hall last.", HORIZONTAL_ALIGNMENT_LEFT, 425, 13, Color("#526168"))
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
	draw_rect(Rect2(p.position + Vector2(220, 275), Vector2(160, 45)), GREEN)
	draw_string(ui_font, p.position + Vector2(265, 304), "RETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _update_monsters(delta: float) -> void:
	for m in monsters:
		var target: int = m.target
		if target < 0 or buildings[target].state == "destroyed":
			target = _nearest_target(m.pos)
			m.target = target
		if target < 0:
			continue
		var destination: Vector2 = _iso(buildings[target].grid)
		if m.pos.distance_to(destination) > 38.0:
			m.pos = m.pos.move_toward(destination, 85.0 * delta)
		else:
			m.cooldown -= delta
			if m.cooldown <= 0.0:
				m.cooldown = 1.05
				_damage(target, 414)

func _update_production(delta: float) -> void:
	for b in buildings:
		if b.state != "intact" or b.produces == "":
			continue
		b.buffer += b.rate * delta
		var amount: int = int(b.buffer)
		if amount > 0:
			resources[b.produces] += amount
			b.buffer -= amount
	# A home represents residents, but only after the city has basic utilities.
	resources.population = 0
	for b in buildings:
		if b.kind == "home" and b.state == "intact":
			resources.population += 4

func _grid_from_mouse(mouse: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var closest := INF
	for x in COLS:
		for y in ROWS:
			var distance: float = mouse.distance_to(_iso(Vector2i(x, y)))
			if distance < closest:
				closest = distance
				best = Vector2i(x, y)
	return best if closest <= 42.0 else Vector2i(-1, -1)

func _occupied(grid: Vector2i) -> bool:
	for b in buildings:
		if b.grid == grid and b.state != "destroyed":
			return true
	return false

func _place_building(id: String, grid: Vector2i) -> void:
	var data := {
		"mint": {"label":"Coin Mint", "kind":"mint", "color":Color("#c89035"), "cost":100, "produces":"coins", "rate":12.0},
		"power": {"label":"Power Plant", "kind":"power", "color":Color("#d6a83d"), "cost":150, "produces":"energy", "rate":4.0},
		"water": {"label":"Water Works", "kind":"water", "color":Color("#4f9ed0"), "cost":150, "produces":"water", "rate":4.0},
		"town": {"label":"Town Hall", "kind":"town", "color":Color("#7189aa"), "cost":400, "produces":"", "rate":0.0}
	}
	if not data.has(id):
		return
	var info: Dictionary = data[id]
	if _occupied(grid):
		adviser = "That space is occupied. Choose an empty tile."
		return
	if resources.coins < info.cost:
		adviser = "You need %d coins to build the %s." % [info.cost, info.label]
		return
	resources.coins -= info.cost
	buildings.append(_make_building(info.label, grid, info.kind, info.color, 500 if id == "town" else 300, "intact", info.produces, info.rate))
	if id == "town":
		build_phase = false
		mission_time = 180.0
		selected_card = "ape"
		adviser = "City founded! Select GIANT APE and destroy the Town Hall target in the next city."
	else:
		adviser = "%s is producing %s. Build the other resource buildings next." % [info.label, info.produces.to_upper()]

func _nearest_target(pos: Vector2) -> int:
	var result := -1
	var nearest := INF
	for i in buildings.size():
		if buildings[i].state == "destroyed" or buildings[i].kind == "gun":
			continue
		var distance: float = pos.distance_to(_iso(buildings[i].grid))
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
	numbers.append({"pos": _iso(b.grid) + Vector2(-15, -55), "value": amount, "life": 0.8})
	particles.append({"pos": _iso(b.grid) + Vector2(0, -25), "life": 0.35, "kind": "hit"})
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

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse: Vector2 = event.position
	if won or lost:
		if Rect2(get_viewport_rect().size * 0.5 + Vector2(-80, 275), Vector2(160, 45)).has_point(mouse):
			_make_city(); monsters.clear(); score = 0; mission_time = 0.0; won = false; lost = false; tutorial = true
		return
	if tutorial:
		var tutorial_button := Rect2(Vector2(get_viewport_rect().size.x * 0.5 + 85.0, 361.0), Vector2(130, 42))
		if tutorial_button.has_point(mouse):
			tutorial = false
			adviser = "Select a production card, then click an empty tile to place it."
		return
	var cards := _card_list()
	for i in cards.size():
		if Rect2(250 + i * 190, HUD_BOTTOM + 2, 176, 108).has_point(mouse):
			selected_card = cards[i].id
			return
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if _iso(b.grid).distance_to(mouse) < 34.0 and b.state != "destroyed":
			selected_building = i
			if b.state == "damaged" and resources.coins >= 120:
				resources.coins -= 120
				b.state = "intact"
				b.hp = b.max_hp
				adviser = "Building repaired! Defense is critical."
			return
	if mouse.y >= HUD_BOTTOM:
		return
	if build_phase and ["mint", "power", "water", "town"].has(selected_card):
		var grid := _grid_from_mouse(mouse)
		if grid.x < 0:
			adviser = "Click inside the city grid to place your building."
		else:
			_place_building(selected_card, grid)
		return
	if selected_card == "ape" and resources.attack > 0:
		resources.attack -= 1
		monsters.append({"kind": "ape", "pos": mouse, "target": _nearest_target(mouse), "cooldown": 0.3})
		adviser = "Giant Ape deployed! Watch the route and protect your population."
	elif selected_card == "bomb" and resources.coins >= 150:
		resources.coins -= 150
		for i in buildings.size():
			if _iso(buildings[i].grid).distance_to(mouse) < 80.0:
				_damage(i, 260)
		particles.append({"pos": mouse, "life": 0.6, "kind": "blast"})
		adviser = "Bomb dropped. Anything in the blast radius takes damage!"

func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
