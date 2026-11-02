extends Node

# Hotbar quick slots, journal "new" badges and sorting, ore container hint
# (SYSTEMS_UX_REVIEW.md §3.3).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

func run(t: Node) -> void:
	SaveSystem.begin_new_game("slot1")
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	var p: Node = w.get_node("Player")
	var bag: Node = p.get_node("Bag")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var journal: Node = UIManager.get_menu("journal")
	bag.deserialize({ "seen": {} })   # empty bag for a clean start
	await _test_hotbar(t, p, bag, hud)
	_test_hotbar_persistence(t, bag)
	await _test_new_badges(t, bag, journal)
	_test_sorting(t, bag, journal)
	_test_container_hint(t, w, p, hud)
	UIManager.close_all()
	w.queue_free()
	await _frames(2)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _test_hotbar(t: Node, p: Node, bag: Node, hud: Node) -> void:
	bag.add_consumable("saline_tonic", 2)
	t._check_eq("first consumable auto-fills slot 1", bag.hotbar_item(0), "saline_tonic")
	bag.add_consumable("saline_tonic", 1)
	t._check_eq("same item does not take a second slot", bag.hotbar_item(1), "")
	t._check_eq("HUD slot shows the count", hud._hotbar_slots[0]["count"].text, "×3")
	t._check("HUD slot shows the icon", hud._hotbar_slots[0]["icon"].texture != null)
	p.hp = 50.0
	var ev := InputEventAction.new()
	ev.action = "hotbar_1"
	ev.pressed = true
	p._unhandled_input(ev)
	t._check_eq("hotbar key heals", p.hp, 90.0)
	t._check_eq("hotbar use decrements", bag.consumable_count("saline_tonic"), 2)
	t._check("game not paused by hotbar", not get_tree().paused)

	UIManager.open("journal")
	t._check("hotbar blocked while a menu is open", not p.use_hotbar_slot(0))
	t._check_eq("nothing used while blocked", bag.consumable_count("saline_tonic"), 2)
	UIManager.close_all()

	p.use_hotbar_slot(0)
	p.use_hotbar_slot(0)
	t._check_eq("used-up slot empties", bag.hotbar_item(0), "")
	t._check_eq("empty HUD slot shows no count", hud._hotbar_slots[0]["count"].text, "")
	t._check("empty slot does nothing", not p.use_hotbar_slot(0))

	bag.add_key_item("co2_canister")
	t._check("Boss Key can be assigned", bag.assign_hotbar(1, "co2_canister"))
	var fired := [""]
	var on_key := func(id: String) -> void: fired[0] = id
	bag.boss_key_requested.connect(on_key)
	t._check("Boss Key slot fires the hook", p.use_hotbar_slot(1) and fired[0] == "co2_canister")
	bag.boss_key_requested.disconnect(on_key)
	t._check("Boss Key is not used up", bag.has_key_item("co2_canister") and bag.hotbar_item(1) == "co2_canister")
	t._check("fragments cannot go on the hotbar", not bag.assign_hotbar(2, "carbon_ember"))
	await _frames(1)

func _test_hotbar_persistence(t: Node, bag: Node) -> void:
	bag.add_consumable("buffer_solution", 1)
	bag.assign_hotbar(3, "buffer_solution")
	t._check("an item lives in one slot only", bag.hotbar.count("buffer_solution") == 1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(bag.serialize()))
	bag.deserialize({ "seen": {} })
	t._check_eq("deserialize of empty data clears slots", bag.hotbar_item(3), "")
	bag.deserialize(data)
	t._check_eq("slot assignment survives save/load", bag.hotbar_item(3), "buffer_solution")
	t._check_eq("Boss Key slot survives save/load", bag.hotbar_item(1), "co2_canister")
	# Older save without a hotbar: held consumables fill the slots.
	bag.deserialize({ "ashmarks": 5, "consumables": { "saline_tonic": 3 }, "key_items": [] })
	t._check_eq("old save loads with auto-filled hotbar", bag.hotbar_item(0), "saline_tonic")
	bag.deserialize(data)

func _test_new_badges(t: Node, bag: Node, journal: Node) -> void:
	bag.mark_all_seen()
	t._check("nothing new after marking seen", not bag.tab_has_new("Consumables"))
	bag.add_consumable("lead_draught", 1)
	t._check("new item flagged", bag.tab_has_new("Consumables") and bag.is_new("Consumables", "lead_draught"))
	UIManager.open("journal")
	journal.show_tab("Elements")
	t._check("ribbon dot on the tab with unseen items", journal.ribbon_has_dot("Consumables"))
	journal.show_tab("Consumables")
	var e: Dictionary = _entry(journal, "lead_draught")
	t._check("row has the new mark", bool(e.get("new", false)))
	t._check("old item has no new mark", not bool(_entry(journal, "buffer_solution").get("new", true)))
	t._check("viewing the tab clears it in the Bag", not bag.tab_has_new("Consumables"))
	journal.show_tab("Elements")
	t._check("ribbon dot cleared", not journal.ribbon_has_dot("Consumables"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(bag.serialize()))
	bag.deserialize(data)
	t._check("seen set survives save/load", not bag.is_new("Consumables", "lead_draught"))
	UIManager.close_all()
	UIManager.open("journal")
	journal.show_tab("Consumables")
	t._check("new mark gone on the next visit", not bool(_entry(journal, "lead_draught").get("new", true)))
	UIManager.close_all()
	await _frames(1)

func _entry(journal: Node, id: String) -> Dictionary:
	for e: Dictionary in journal._entries:
		if str(e["id"]) == id:
			return e
	return {}

func _test_sorting(t: Node, bag: Node, journal: Node) -> void:
	bag.deserialize({ "seen": {} })
	bag.add_consumable("saline_tonic")
	bag.add_consumable("buffer_solution")
	bag.add_consumable("lead_draught")
	UIManager.open("journal")
	journal.show_tab("Consumables")
	t._check_eq("default sort is Recent", journal.sort_mode_name(), "Recent")
	t._check_eq("Recent: newest first", journal.entry_ids(), ["lead_draught", "buffer_solution", "saline_tonic"])
	var s := InputEventKey.new()
	s.keycode = KEY_S
	s.pressed = true
	journal._unhandled_input(s)
	t._check_eq("S cycles to Name", journal.sort_mode_name(), "Name")
	t._check_eq("Name: A–Z", journal.entry_ids(), ["buffer_solution", "lead_draught", "saline_tonic"])
	journal.cycle_sort()
	t._check_eq("then Type", journal.sort_mode_name(), "Type")
	t._check_eq("Type: by effect", journal.entry_ids(), ["buffer_solution", "saline_tonic", "lead_draught"])
	journal.cycle_sort()
	t._check_eq("and back to Recent", journal.sort_mode_name(), "Recent")

	# Assigning from the journal: button row and Shift+number.
	journal.select_id("lead_draught")
	t._check("journal assigns to slot 4", journal.assign_selected_to_hotbar(3) and bag.hotbar_item(3) == "lead_draught")
	var k := InputEventKey.new()
	k.keycode = KEY_2
	k.shift_pressed = true
	k.pressed = true
	journal.select_id("saline_tonic")
	journal._unhandled_input(k)
	t._check_eq("Shift+2 assigns to slot 2", bag.hotbar_item(1), "saline_tonic")
	t._check_eq("Shift+2 does not switch tab", journal.TAB_NAMES[journal._tab], "Consumables")
	UIManager.close_all()

func _test_container_hint(t: Node, w: Node, p: Node, hud: Node) -> void:
	var eq: Node = p.get_node("Equipment")
	eq.deserialize({ "Standard Vial": 5, "Nitrile Gloves": 1 })
	var fe: Dictionary = hud.container_hint("Fe")
	t._check_eq("collectable hint text", fe["text"], "Fe → Standard Vial ✓")
	t._check("collectable hint ok", fe["ok"])
	var u: Dictionary = hud.container_hint("U")
	t._check("non-collectable hint not ok", not u["ok"])
	t._check("non-collectable hint names the container", str(u["text"]).begins_with("U → needs") and "Lead Container" in str(u["text"]))
	t._check("hint agrees with Equipment.can_collect", (eq.can_collect("U") == "") == u["ok"] and (eq.can_collect("Fe") == "") == fe["ok"])

	# Standing next to an ore tile shows the hint on the HUD.
	var ore := Vector2i(-1, -1)
	for c: Vector2i in w.tile_data:
		if w.tile_data[c].get("type", "") == "ore":
			ore = c
			break
	t._check("world has an ore tile", ore != Vector2i(-1, -1))
	p.global_position = (Vector2(ore) + Vector2(0.5, 1.5)) * 16.0
	hud.update_ore_hint()
	var sym: String = str(w.tile_data[ore]["element"])
	t._check("HUD shows the ore hint in dig range", hud._ore_hint.visible and hud._ore_hint_label.text.begins_with(sym + " →"))
	p.global_position = Vector2(-5000, -5000)
	hud.update_ore_hint()
	t._check("hint hidden away from ore", not hud._ore_hint.visible)

	# Low-vial toast.
	eq.deserialize({ "Standard Vial": 4 })
	hud._last_vials = 4
	eq.use_container("Standard Vial")
	var toasted := false
	for c: Node in hud.get_children():
		if c is Label and c.text == "Only 3 Standard Vials left":
			toasted = true
	t._check("toast when vials drop to 3", toasted)
