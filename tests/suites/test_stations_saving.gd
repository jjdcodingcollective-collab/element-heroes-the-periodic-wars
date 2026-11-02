extends Node

# Field Stations, autosave, fast travel + map, Suspend (SYSTEMS_UX_REVIEW.md §3.1).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

func run(t: Node) -> void:
	SaveSystem.begin_new_game("slot3")
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	_test_placement(t, w)
	await _test_station_menu(t, w)
	await _test_travel_and_map(t, w)
	await _test_autosave(t, w)
	await _test_suspend(t, w)
	var positions: Dictionary = {}
	for id: String in w.stations:
		positions[id] = w.stations[id].global_position
	SaveSystem.save_game(w.get_node("Player"))
	w.queue_free()
	await _frames(2)
	await _test_discovery_persists(t, positions)
	await _test_old_save_without_stations(t)
	for s: String in ["slot3", "autosave", "suspend"]:
		SaveSystem.delete_slot(s)
	SaveSystem.begin_new_game("slot1")
	await _frames(1)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _boss(w: Node, id: String) -> Node:
	for c: Node in w.get_children():
		if "boss_id" in c and c.boss_id == id:
			return c
	return null

# Ashvale, every biome entrance and every boss arena has a station.
func _test_placement(t: Node, w: Node) -> void:
	t._check("Ashvale station placed", w.stations.has("ashvale"))
	var ash: Node2D = w.stations.get("ashvale")
	t._check("Ashvale station is in the village", ash != null and ash.global_position.distance_to(w.PLAYER_SPAWN) < 16.0 * 14.0)
	for biome: Dictionary in w.BIOMES:
		var has_one := false
		for id: String in w.stations:
			var tile: Vector2i = w.world_to_tile(w.stations[id].global_position)
			if not id.begins_with("boss_") and tile.x >= int(biome.x_start) and tile.x <= int(biome.x_end):
				has_one = true
		t._check("biome has an entrance station: %s" % biome.name, has_one)
	for biome_name: String in w.BIOME_BOSSES:
		var boss_id: String = w.BIOME_BOSSES[biome_name]
		var st: Node2D = w.stations.get("boss_" + boss_id)
		t._check("boss station placed: %s" % boss_id, st != null)
		if st == null:
			continue
		var boss_pos: Vector2 = w._tile_centre(w.boss_tiles[boss_id])
		var d: float = st.global_position.distance_to(boss_pos)
		t._check("%s station outside its arena" % boss_id, d > w.boss_arena_radius(boss_id) and d < w.boss_arena_radius(boss_id) + 16.0 * 12.0)
		var tile: Vector2i = w.world_to_tile(st.global_position)
		t._check("%s station on open ground" % boss_id, w.tile_data[tile].get("passable", false))
		var boss: Node2D = _boss(w, boss_id)
		t._check("%s stands where its station expects" % boss_id, boss != null and boss.global_position.distance_to(boss_pos) < 64.0)
	t._check("stations are crafting benches", w.stations["ashvale"].is_in_group("crafting_bench") and "interact_radius" in w.stations["ashvale"])
	t._check("nothing discovered at the start", w.discovered_stations.is_empty())

# F at a station opens the station menu; Save and Rest work.
func _test_station_menu(t: Node, w: Node) -> void:
	var p: Node2D = w.get_node("Player")
	var ash: Node2D = w.stations["ashvale"]
	SaveSystem.delete_slot("autosave")
	p.global_position = ash.arrival_position()
	var f := InputEventAction.new()
	f.action = "interact"
	f.pressed = true
	p._unhandled_input(f)
	t._check("F at a station opens the station menu", UIManager.is_open("station"))
	t._check("station menu pauses the game", get_tree().paused)
	t._check("first visit discovers the station", "ashvale" in w.discovered_stations and ash.discovered)
	t._check("discovery autosaves", SaveSystem.slot_exists("autosave") and w.get_node("Autosave").last_reason == "station")
	var menu: Node = UIManager.get_menu("station")
	t._check("menu knows its station", menu.current_station() == ash)
	t._check("Travel disabled with one station", menu._travel_btn.disabled)
	SaveSystem.delete_slot("slot3")
	t._check("Save writes the active slot", menu.do_save() and SaveSystem.slot_exists("slot3"))
	t._check("save records discovered stations", SaveSystem.read_slot("slot3").get("stations", []) == ["ashvale"])
	p.hp = 12.0
	t._check("Rest", menu.do_rest())
	t._check_eq("Rest fully heals", p.hp, p.get_max_health())
	UIManager.close("station")
	t._check("station menu closes and unpauses", not UIManager.is_open() and not get_tree().paused)
	await _frames(1)

# Travel from a station's menu; the map is view-only elsewhere.
func _test_travel_and_map(t: Node, w: Node) -> void:
	var p: Node2D = w.get_node("Player")
	var target := "entrance_underground_mines"
	w.on_station_discovered(target)
	t._check("second station discovered", target in w.discovered_stations)
	var menu: Node = UIManager.get_menu("station")
	menu.open_for(w.stations["ashvale"])
	t._check("Travel enabled with two stations", not menu._travel_btn.disabled)
	menu.do_travel()
	var map: Node = UIManager.get_menu("map")
	t._check("Travel opens the map for travel", UIManager.is_open("map") and map.can_travel())
	t._check("map lists discovered stations", map._list.get_child_count() == 2)
	t._check("can't travel to where you are", not map.travel_to("ashvale"))
	t._check("travel succeeds", map.travel_to(target))
	t._check("travel moves the player", p.global_position.distance_to(w.stations[target].arrival_position()) < 1.0)
	t._check("travel closes the map", not UIManager.is_open() and not get_tree().paused)
	await _frames(2)
	t._check("entering a new biome autosaves", w.get_node("Autosave").last_reason == "biome")
	# M at a station: travel too. M in the wild: view only.
	UIManager.open("map")
	t._check("map at a station allows travel", map.can_travel())
	UIManager.close("map")
	p.global_position = w.stations[target].global_position + Vector2(400, 0)
	UIManager.open("map")
	t._check("map elsewhere is view-only", UIManager.is_open("map") and not map.can_travel())
	t._check("view-only map won't travel", not map.travel_to("ashvale"))
	t._check("map draws the world", map._canvas.world == w)
	UIManager.close("map")
	t._check("undiscovered station refuses travel", not w.travel_to_station("boss_uranox"))
	w.travel_to_station("ashvale")
	await _frames(2)

# Autosave on boss defeat and on the 5-minute timer; never while dead or in a boss fight.
func _test_autosave(t: Node, w: Node) -> void:
	var p: Node2D = w.get_node("Player")
	var auto: Node = w.get_node("Autosave")
	SaveSystem.delete_slot("autosave")
	w.on_boss_defeated("chalcor")
	t._check("boss defeat autosaves", SaveSystem.slot_exists("autosave") and auto.last_reason == "boss")
	t._check("autosave records the beaten boss", "chalcor" in SaveSystem.read_slot("autosave").get("defeated_bosses", []))

	SaveSystem.delete_slot("autosave")
	p.is_dead = true
	auto.request("boss")
	t._check("no autosave while dead", not SaveSystem.slot_exists("autosave"))
	p.is_dead = false
	await _frames(1)
	t._check("deferred autosave fires after recovery", SaveSystem.slot_exists("autosave"))

	var boss: Node = _boss(w, "peroxis")
	if boss:
		SaveSystem.delete_slot("autosave")
		var home := p.global_position
		boss._state = "combat"
		p.global_position = boss.global_position + Vector2(40, 0)
		t._check("boss fight detected", w.is_boss_fight_active())
		auto.request("timer")
		t._check("no autosave during a boss fight", not SaveSystem.slot_exists("autosave"))
		p.global_position = home
		boss._state = "idle"
		await _frames(1)
		t._check("autosave once the fight is over", SaveSystem.slot_exists("autosave"))

	SaveSystem.delete_slot("autosave")
	auto.interval = 0.15
	get_tree().paused = true
	await get_tree().create_timer(0.3, true).timeout
	t._check("timer doesn't count while paused", not SaveSystem.slot_exists("autosave"))
	get_tree().paused = false
	await get_tree().create_timer(0.3).timeout
	t._check("timer autosaves", SaveSystem.slot_exists("autosave") and auto.last_reason == "timer")
	auto.interval = auto.INTERVAL

# Suspend writes the suspend slot and heads for the title.
func _test_suspend(t: Node, w: Node) -> void:
	var p: Node2D = w.get_node("Player")
	SaveSystem.delete_slot("suspend")
	UIManager.open("map")
	SaveSystem.title_scene = ""   # stay in the test runner
	var ok: bool = SaveSystem.suspend_and_quit(p)
	SaveSystem.title_scene = SaveSystem.TITLE_SCENE
	t._check("suspend writes the suspend slot", ok and SaveSystem.slot_exists("suspend"))
	t._check("suspend closes menus and unpauses", not UIManager.is_open() and not get_tree().paused)
	t._check("suspend file has the stations", "ashvale" in SaveSystem.read_slot("suspend").get("stations", []))
	t._check("title scene exists", ResourceLoader.exists(SaveSystem.TITLE_SCENE))
	SaveSystem.delete_slot("suspend")

func _test_discovery_persists(t: Node, positions: Dictionary) -> void:
	t._check("load the station save", SaveSystem.begin_load("slot3"))
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	t._check("discovered stations restored", "ashvale" in w.discovered_stations and "entrance_underground_mines" in w.discovered_stations)
	t._check("station flags restored", w.stations["ashvale"].discovered and not w.stations["boss_uranox"].discovered)
	var same := true
	for id: String in positions:
		if not w.stations.has(id) or w.stations[id].global_position.distance_to(positions[id]) > 0.5:
			same = false
	t._check("stations in the same places after load", same)
	t._check("restored station allows travel", w.travel_to_station("entrance_underground_mines"))
	w.queue_free()
	await _frames(2)

# "stations" is optional: a save without it loads with nothing discovered.
func _test_old_save_without_stations(t: Node) -> void:
	var data := SaveSystem.read_slot("slot3")
	data.erase("stations")
	data["position"] = { "x": 192, "y": 192 }   # away from any station
	SaveSystem.write_slot("slot3", data)
	t._check("old save loads", SaveSystem.begin_load("slot3"))
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	t._check("old save: no stations discovered", w.discovered_stations.is_empty() and w.stations.size() == 12)
	w.queue_free()
	await _frames(2)
