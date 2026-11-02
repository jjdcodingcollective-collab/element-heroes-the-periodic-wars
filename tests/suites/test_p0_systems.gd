extends Node

# P0 systems (SYSTEMS_UX_REVIEW.md): menus, saving and loading, title screen.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const TITLE_SCENE := preload("res://scenes/ui/title_screen.tscn")

func run(t: Node) -> void:
	await _test_menus(t)
	await _test_save_load_roundtrip(t)
	await _test_slots_and_title(t)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

# One menu at a time, every menu pauses, Esc closes, crafting is reachable.
func _test_menus(t: Node) -> void:
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	for m: String in ["journal", "compendium", "crafting", "synthesizer", "quiz", "dialogue"]:
		t._check("menu registered: %s" % m, UIManager.has_menu(m))
	UIManager.open("crafting")
	t._check("crafting opens (was unreachable)", UIManager.is_open("crafting") and UIManager.get_menu("crafting").visible)
	t._check("menu pauses the game", get_tree().paused)
	UIManager.open("compendium")
	t._check("opening another menu closes the first", not UIManager.get_menu("crafting").visible and UIManager.is_open("compendium"))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	UIManager._unhandled_input(esc)
	t._check("Esc closes the compendium", not UIManager.is_open() and not UIManager.get_menu("compendium").visible)
	t._check("game resumes", not get_tree().paused)
	var key := InputEventAction.new()
	key.action = "open_crafting"
	key.pressed = true
	UIManager._unhandled_input(key)
	t._check("R opens crafting", UIManager.is_open("crafting"))
	UIManager._unhandled_input(key)
	t._check("R closes crafting while paused", not UIManager.is_open())
	var dlg: Node = UIManager.get_menu("dialogue")
	dlg.show_dialogue("Test", ["Hello."] as Array[String])
	t._check("dialogue pauses", get_tree().paused and dlg.is_open())
	UIManager.close_all()
	w.queue_free()
	await _frames(2)

# Save a changed world, load it into a brand-new world: same map and progress.
func _test_save_load_roundtrip(t: Node) -> void:
	SaveSystem.begin_new_game("slot2")
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	var p: Node = w.get_node("Player")
	var seed_before: int = w.world_seed
	p.global_position = Vector2(300, 260)
	p.get_node("Bag").add_ashmarks(77)
	p.get_node("Bag").add_key_item("carbon_ember")
	p.get_node("Inventory").add_element("Cu", 3.5)
	w.on_boss_defeated("peroxis")
	var comp: Node = get_tree().get_first_node_in_group("compendium")
	comp.mark_discovered("Cu")
	var saved := [false]
	var on_saved := func(slot: String, ok: bool) -> void: saved[0] = ok and slot == "slot2"
	SaveSystem.saved.connect(on_saved)
	t._check("save writes the active slot", SaveSystem.save_game(p) and saved[0])
	SaveSystem.saved.disconnect(on_saved)
	w.queue_free()
	await _frames(2)

	t._check("begin_load reads the slot", SaveSystem.begin_load("slot2"))
	var w2: Node = WORLD_SCENE.instantiate()
	add_child(w2)
	await _frames(3)
	var p2: Node = w2.get_node("Player")
	t._check_eq("same world seed after load", w2.world_seed, seed_before)
	t._check("position restored", p2.global_position.distance_to(Vector2(300, 260)) < 1.0)
	t._check_eq("Ashmarks restored", p2.get_node("Bag").ashmarks, 77)
	t._check("key item restored", p2.get_node("Bag").has_key_item("carbon_ember"))
	t._check("defeated boss stays beaten", "peroxis" in w2.defeated_bosses and not _boss_present(w2, "peroxis"))
	var comp2: Node = get_tree().get_first_node_in_group("compendium")
	t._check("compendium restored", comp2.discovered.has("Cu"))
	t._check("pending load consumed", not SaveSystem.has_pending())
	w2.queue_free()
	await _frames(2)

func _boss_present(w: Node, id: String) -> bool:
	for c: Node in w.get_children():
		if "boss_id" in c and c.boss_id == id:
			return true
	return false

func _test_slots_and_title(t: Node) -> void:
	var info := SaveSystem.slot_summary("slot2")
	t._check("slot card summary", info.get("ashmarks", 0) == 77 and str(info.get("timestamp", "")) != "")
	t._check("empty slot has no summary", SaveSystem.slot_summary("slot3").is_empty())
	t._check_eq("continue picks newest save", SaveSystem.most_recent_slot(), "slot2")
	SaveSystem.write_slot("suspend", SaveSystem.read_slot("slot2"))
	t._check_eq("continue prefers a suspend", SaveSystem.most_recent_slot(), "suspend")
	SaveSystem.begin_load("suspend")
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	t._check("suspend is consumed on resume", not SaveSystem.slot_exists("suspend"))
	w.queue_free()
	await _frames(2)
	# Corrupt file: ignored, not a crash.
	var f := FileAccess.open(SaveSystem.slot_path("slot3"), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	t._check("corrupt slot reads as empty", SaveSystem.read_slot("slot3").is_empty())
	SaveSystem.delete_slot("slot3")

	var title: Control = TITLE_SCENE.instantiate()
	add_child(title)
	await _frames(1)
	t._check("title: Continue enabled with a save", not title._continue_btn.disabled)
	title._set_mode(title.Mode.LOAD)
	t._check("title: load lists slots", title._cards.get_child_count() >= 3)
	title._set_mode(title.Mode.NEW)
	title._on_slot_chosen("slot2")
	t._check("title: overwriting needs a second click", title._confirm_slot == "slot2")
	title.queue_free()
	SaveSystem.begin_new_game("slot1")
	await _frames(1)
