extends Node

# Contents hub, Options, Bestiary, journal export / import and the Specimen
# Cabinet (SYSTEMS_UX_REVIEW.md §3.1, §3.2, §3.4, §3.5).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const SaveTransfer := preload("res://scripts/data/save_transfer.gd")
const PrimeSet := preload("res://scripts/world/prime_set.gd")

var _settings_path_before: String = ""

func run(t: Node) -> void:
	EncounterSystem.reset()
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	await _test_contents(t, w)
	await _test_options(t)
	await _test_keep_inventory(t, w)
	await _test_bestiary(t)
	await _test_transfer(t, w)
	await _test_cabinet(t, w)
	_restore_options()
	EncounterSystem.reset()
	UIManager.close_all()
	w.queue_free()
	await _frames(2)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _esc() -> void:
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	UIManager._unhandled_input(esc)

# ── Contents hub ──────────────────────────────────────────────────────────────

func _test_contents(t: Node, w: Node) -> void:
	for m: String in ["contents", "options", "bestiary", "cabinet"]:
		t._check("menu registered: %s" % m, UIManager.has_menu(m))
	UIManager.close_all()
	_esc()
	t._check("Esc with nothing open opens Contents", UIManager.is_open("contents"))
	t._check("Contents pauses the game", get_tree().paused)
	var hub: Node = UIManager.get_menu("contents")
	t._check("Contents page is visible", hub.is_open())
	for pair: Array in [["items", "journal"], ["crafting", "crafting"], ["compendium", "compendium"],
			["bestiary", "bestiary"], ["options", "options"]]:
		UIManager.open("contents")
		hub.open_section(pair[0])
		t._check("Contents → %s opens '%s'" % [pair[0], pair[1]], UIManager.is_open(pair[1]) and not hub.is_open())
	UIManager.open("contents")
	var map_i: int = hub.section_index("map")
	t._check_eq("Map section enabled only when a map menu exists", hub.section_enabled(map_i), UIManager.has_menu("map"))
	if not UIManager.has_menu("map"):
		t._check("disabled Map does not open", not hub.open_section("map") and UIManager.is_open("contents"))

	# Save & Quit: Save needs a Field Station in range.
	hub._select(hub.section_index("save"))
	t._check("Save & Quit shows its buttons", hub.save_button.visible and hub.quit_button.visible and hub.suspend_button.visible)
	t._check("Save disabled away from a Field Station", hub.save_button.disabled and hub.save_button.text == "Save at a Field Station")
	t._check_eq("Suspend enabled only when SaveSystem supports it", hub.suspend_button.disabled, not SaveSystem.has_method("suspend_and_quit"))
	var p: Node2D = w.get_node("Player")
	var station := Node2D.new()
	station.add_to_group("field_station")
	station.set_meta("test", true)
	w.add_child(station)
	station.global_position = p.global_position + Vector2(20, 0)
	hub._select(hub.section_index("save"))
	t._check("Save enabled within a Field Station's range", not hub.save_button.disabled)
	SaveSystem.delete_slot(SaveSystem.active_slot)
	hub._on_save()
	t._check("Save at a station writes the journal", SaveSystem.slot_exists(SaveSystem.active_slot))
	station.global_position = p.global_position + Vector2(400, 0)
	hub._select(hub.section_index("save"))
	t._check("Save disabled again out of range", hub.save_button.disabled)
	station.queue_free()
	_esc()
	t._check("Esc closes Contents and resumes", not UIManager.is_open() and not get_tree().paused)
	await _frames(1)

# ── Options ───────────────────────────────────────────────────────────────────

func _test_options(t: Node) -> void:
	var opts: Node = get_node("/root/OptionsMenu")
	_settings_path_before = opts.settings_path
	opts.settings_path = SaveSystem.save_dir.path_join("test_settings.cfg")
	opts.reset_to_defaults()
	t._check("Keep Inventory defaults ON", opts.keep_inventory)
	opts.set_music_volume(0.5)
	t._check("music volume applies live", absf(AudioManager.music_volume_db - linear_to_db(0.5)) < 0.01
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) < 0.01)
	opts.set_sfx_volume(0.25)
	t._check("sfx volume applies live", absf(AudioManager.sfx_volume_db - linear_to_db(0.25)) < 0.01)
	opts.set_text_speed("fast")
	opts.set_keep_inventory(false)
	t._check("settings file written", FileAccess.file_exists(opts.settings_path))
	# Forget in memory (without saving), then load from the file.
	opts.music_volume = 1.0
	opts.sfx_volume = 1.0
	opts.text_speed = "normal"
	opts.keep_inventory = true
	opts.load_settings()
	t._check("settings persist: volumes", is_equal_approx(opts.music_volume, 0.5) and is_equal_approx(opts.sfx_volume, 0.25))
	t._check("settings persist: text speed and keep inventory", opts.text_speed == "fast" and not opts.keep_inventory)
	var dlg: Node = UIManager.get_menu("dialogue")
	t._check_eq("dialogue uses the text speed", dlg._chars_per_second(), 80.0)
	UIManager.open("options")
	t._check("options page shows the saved values", is_equal_approx(opts.music_slider.value, 50.0) and not opts.keep_check.button_pressed)
	opts.sfx_slider.value = 60
	t._check("sfx slider changes volume", is_equal_approx(opts.sfx_volume, 0.6))
	UIManager.close("options")
	var cfg := ConfigFile.new()
	cfg.load(opts.settings_path)
	t._check("closing Options saves slider changes", is_equal_approx(float(cfg.get_value("audio", "sfx_volume", 0.0)), 0.6))
	await _frames(1)

func _restore_options() -> void:
	var opts: Node = get_node("/root/OptionsMenu")
	DirAccess.remove_absolute(opts.settings_path)
	opts.settings_path = _settings_path_before
	opts.load_settings()

# ── Keep Inventory off: drop and recover Ashmarks ─────────────────────────────

func _test_keep_inventory(t: Node, w: Node) -> void:
	var opts: Node = get_node("/root/OptionsMenu")
	opts.set_keep_inventory(false, false)
	var p: Node2D = w.get_node("Player")
	var bag: Node = p.get_node("Bag")
	bag.ashmarks = 41
	var death_pos := Vector2(640, 560)
	p.global_position = death_pos
	p._invincible_timer = 0.0
	p.take_damage(99999.0)
	await _frames(2)
	t._check("player died", p.is_dead)
	t._check_eq("half the Ashmarks dropped (rounded up)", bag.ashmarks, 20)
	var cache: Node2D = get_tree().get_first_node_in_group("ashmark_cache")
	t._check("an Ashmark cache marks the spot", cache != null and cache.global_position.distance_to(death_pos) < 1.0)
	t._check_eq("cache holds the dropped Ashmarks", cache.amount if cache else -1, 21)
	var hud: Node = w.get_node("HUD")
	await get_tree().create_timer(1.0).timeout   # death screen fades in
	hud._dismiss_death_screen()   # "press any key": respawn in Ashvale
	await _frames(2)
	t._check("respawned away from the cache", not p.is_dead and bag.ashmarks == 20 and is_instance_valid(cache))
	p.global_position = cache.global_position
	await _frames(3)
	t._check_eq("walking over the cache recovers the Ashmarks", bag.ashmarks, 41)
	t._check("cache is gone once collected", not is_instance_valid(cache) or cache.is_queued_for_deletion())
	await _frames(1)

	opts.set_keep_inventory(true, false)
	p._invincible_timer = 0.0
	p.take_damage(99999.0)
	await _frames(2)
	t._check("Keep Inventory on: nothing dropped", bag.ashmarks == 41 and get_tree().get_first_node_in_group("ashmark_cache") == null)
	await get_tree().create_timer(1.0).timeout
	hud._dismiss_death_screen()
	await _frames(1)

# ── Bestiary ──────────────────────────────────────────────────────────────────

func _test_bestiary(t: Node) -> void:
	EncounterSystem.reset()
	var b: Node = UIManager.get_menu("bestiary")
	UIManager.open("bestiary")
	t._check_eq("bestiary lists all 18 creatures", b._rows.size(), 18)
	t._check_eq("unseen creature shows ???", b.entry_name("iron_hulk"), "???")
	t._check_eq("unseen file has no lore", b.file_text("iron_hulk")["name"], "???")
	EncounterSystem.mark_seen("iron_hulk")
	EncounterSystem.record_defeat("copper_coil", "shiny")
	EncounterSystem.record_defeat("copper_coil", "normal")
	b.refresh()
	t._check_eq("seen creature shows its name", b.entry_name("iron_hulk"), "Iron Hulk")
	t._check_eq("defeating a creature marks it seen", b.entry_name("copper_coil"), "Copper Coil")
	var f: Dictionary = b.file_text("copper_coil")
	t._check("file shows lore and base animal", str(f["text"]).contains("copper") and str(f["meta"]).contains("King cobra"))
	t._check("file shows defeats by rarity", str(f["stat"]).contains("Defeated: 2") and str(f["stat"]).contains("1 shiny"))
	t._check_eq("base animal for a reverted creature", PrimeSet.base_animal("potash_poltergeist"), "Cane toad")
	# Saves: new fields round-trip; old saves (no seen data) still load.
	var data := EncounterSystem.serialize()
	EncounterSystem.reset()
	t._check("reset clears sightings", not EncounterSystem.is_seen("iron_hulk"))
	EncounterSystem.deserialize(data)
	t._check("sightings and per-creature defeats round-trip", EncounterSystem.is_seen("iron_hulk")
		and int(EncounterSystem.defeats_of("copper_coil").get("shiny", 0)) == 1)
	EncounterSystem.deserialize({ "encounters": 5, "prime_codex": ["gold_golem"] })
	t._check("old encounter data loads (Primes count as seen)", EncounterSystem.is_seen("gold_golem")
		and not EncounterSystem.is_seen("iron_hulk") and EncounterSystem.encounters == 5)
	EncounterSystem.reset()
	EncounterSystem.record_defeat("ashburn_shambler", "prime")
	b.show_tab(1)
	t._check("Prime Codex tab marks recorded Primes", b._row_note(b._rows[0]).text == "◆" and b._row_note(b._rows[1]).text == "◇")
	var ms: Array = PrimeSet.milestones(EncounterSystem.prime_codex)
	t._check("first Prime unlocks the Prime Lens", ms[0]["name"] == "Prime Lens" and ms[0]["unlocked"])
	t._check("Prime Satchel still locked", not ms[ms.size() - 2]["unlocked"])
	UIManager.close("bestiary")
	EncounterSystem.reset()
	await _frames(1)

# ── Export / import ───────────────────────────────────────────────────────────

func _test_transfer(t: Node, w: Node) -> void:
	var exports_before := SaveTransfer.exports_dir
	var imports_before := SaveTransfer.imports_dir
	SaveTransfer.exports_dir = SaveSystem.save_dir.path_join("exports")
	SaveTransfer.imports_dir = SaveSystem.save_dir.path_join("imports")
	var p: Node = w.get_node("Player")
	p.get_node("Bag").ashmarks = 123
	SaveSystem.save_game(p, "slot2")
	var data := SaveSystem.read_slot("slot2")

	var code := SaveTransfer.encode(data)
	t._check("code is compact text", code.begins_with(SaveTransfer.CODE_PREFIX) and not code.contains("{"))
	var back := SaveTransfer.decode(code)
	t._check("decode(encode(save)) round-trips", back["ok"] and JSON.stringify(back["data"]) == JSON.stringify(data))
	var raw := SaveTransfer.decode(JSON.stringify(data))
	t._check("plain journal JSON decodes too", raw["ok"] and int(raw["data"]["bag"]["ashmarks"]) == 123)

	var ex := SaveTransfer.export_slot("slot2")
	t._check("export writes a file", ex["ok"] and FileAccess.file_exists(ex["path"]))
	t._check("export returns the code", ex["code"] == code)
	SaveSystem.delete_slot("slot3")
	var im := SaveTransfer.import_into("slot3", ex["code"])
	t._check("import code into an empty slot", im["ok"] and SaveSystem.slot_exists("slot3"))
	t._check_eq("imported journal matches", int(SaveSystem.slot_summary("slot3").get("ashmarks", -1)), 123)
	t._check("export of an empty slot is refused", not SaveTransfer.export_slot("slot1_missing")["ok"])

	# Desktop: import the newest file from the imports folder.
	DirAccess.make_dir_recursive_absolute(SaveTransfer.imports_dir)
	var data2 := data.duplicate(true)
	data2["bag"]["ashmarks"] = 7
	data2["summary"]["ashmarks"] = 7
	var f := FileAccess.open(SaveTransfer.imports_dir.path_join("journal.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data2))
	f.close()
	var newest := SaveTransfer.newest_import_file()
	t._check("finds the file in imports", newest.ends_with("journal.json"))
	t._check("imports a journal file", SaveTransfer.import_into("slot3", SaveTransfer.read_text_file(newest))["ok"]
		and int(SaveSystem.slot_summary("slot3").get("ashmarks", -1)) == 7)

	# Corrupt or foreign input is rejected and leaves the slot alone.
	var mid := code.length() / 2
	var tampered := code.substr(0, mid) + ("A" if code[mid] != "A" else "B") + code.substr(mid + 1)
	var bad := ["", "hello", "EHJ1.notbase64!!", "EHJ1.QUJD.12345678", tampered, "{ not json",
		"{\"foo\": 1}", "{\"version\": 99, \"inventory\": {}}", "[1, 2, 3]"]
	var all_rejected := true
	for b: String in bad:
		var r := SaveTransfer.decode(b)
		if r["ok"] or str(r["error"]) == "":
			all_rejected = false
			printerr("    accepted bad input: %s" % b.left(40))
	t._check("corrupt, tampered, foreign and newer journals are rejected", all_rejected)
	t._check("failed import leaves the slot unchanged", not SaveTransfer.import_into("slot3", "EHJ1.garbage")["ok"]
		and int(SaveSystem.slot_summary("slot3").get("ashmarks", -1)) == 7)
	var old := SaveTransfer.decode(JSON.stringify({ "version": 4, "inventory": {} }))
	t._check("older journals are migrated", old["ok"] and int(old["data"]["version"]) == SaveSystem.SAVE_VERSION)

	# Options → Journal transfer: an occupied slot needs a second press.
	var opts: Node = get_node("/root/OptionsMenu")
	opts.show_transfer()
	t._check("transfer tab opens", UIManager.is_open("options") and opts._transfer_box.visible)
	opts.import_slot_pick.select(2)   # slot3, in use
	opts._confirm_import_slot = ""
	t._check("import over a journal asks first", not opts._import_text(code))
	t._check("second press replaces it", opts._import_text(code) and int(SaveSystem.slot_summary("slot3").get("ashmarks", -1)) == 123)
	t._check("options import rejects junk", not opts._import_text("not a journal"))
	UIManager.close("options")

	for dir_path: String in [SaveTransfer.exports_dir, SaveTransfer.imports_dir]:
		var d := DirAccess.open(dir_path)
		if d:
			for fname: String in d.get_files():
				d.remove(fname)
			DirAccess.remove_absolute(dir_path)
	SaveSystem.delete_slot("slot2")
	SaveSystem.delete_slot("slot3")
	SaveTransfer.exports_dir = exports_before
	SaveTransfer.imports_dir = imports_before
	await _frames(1)

# ── Specimen Cabinet ──────────────────────────────────────────────────────────

func _test_cabinet(t: Node, w: Node) -> void:
	EncounterSystem.reset()
	for id: String in ["ashburn_shambler", "carbon_crawler", "potash_poltergeist"]:
		EncounterSystem.record_defeat(id, "prime")
	EncounterSystem.record_defeat("iron_hulk", "shiny")
	EncounterSystem.record_defeat("iron_hulk", "strong")
	EncounterSystem.record_defeat("iron_hulk", "strong")
	w.on_boss_defeated("peroxis")
	var cabinet: Node2D = w.get_node_or_null("SpecimenCabinet")
	t._check("cabinet stands in Aldric's workshop", cabinet != null
		and Rect2(160, 160, 80, 64).has_point(cabinet.position))
	var p: Node2D = w.get_node("Player")
	p.global_position = cabinet.global_position + Vector2(22, 0)
	var f_key := InputEventAction.new()
	f_key.action = "interact"
	f_key.pressed = true
	p._unhandled_input(f_key)
	t._check("F at the cabinet opens its page", UIManager.is_open("cabinet"))
	var page: Node = UIManager.get_menu("cabinet")
	var tr: Dictionary = page.trophies()
	t._check_eq("cabinet shows Prime Codex count", tr["codex"], 3)
	t._check("cabinet shows rare defeat counts", tr["prime"] == 3 and tr["shiny"] == 1 and tr["strong"] == 2)
	t._check("cabinet shows defeated bosses", "peroxis" in tr["bosses"])
	t._check("cabinet shows unlocked Prime set pieces", "Prime Lens" in tr["prime_set"] and "Ember Prime Patch" in tr["prime_set"]
		and not "Prime Satchel" in tr["prime_set"])
	t._check("cabinet page lists the jars", page._shelf.get_child_count() == 18)
	UIManager.close("cabinet")
	p.global_position = cabinet.global_position + Vector2(200, 0)
	p._unhandled_input(f_key)
	t._check("cabinet ignores F from far away", not UIManager.is_open("cabinet"))
	await _frames(1)
