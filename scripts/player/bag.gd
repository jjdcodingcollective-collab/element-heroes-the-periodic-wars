extends Node

# Bag — Ashmarks (currency), consumables and key items. Child "Bag" of Player.
# Elements live in Inventory and lab gear in Equipment; this holds everything
# else the inventory screen shows on its Consumables and Key Items tabs.
#
# Key items (Key Fragments, Boss Keys) are permanent: once earned they are never
# removed, except fragments, which are absorbed when combined into their Boss Key.
# Item definitions: data/items.json.

signal bag_changed
signal hotbar_changed
signal boss_key_requested(id: String)   # hotbar Boss Key pressed (boss use comes later)

const ITEMS_PATH := "res://data/items.json"
const STACK_MAX: int = 99   # consumables stack to 99 (D-018)

var ashmarks: int = 0
var consumables: Dictionary = {}   # id -> count
var key_items: Dictionary = {}     # id -> true

# Quick slots (SYSTEMS_UX_REVIEW.md §3.3): item ids, "" = empty. Consumables
# and Boss Keys only.
const HOTBAR_SIZE: int = 4
var hotbar: Array = ["", "", "", ""]

# Journal "new" badges and Recent sort. Keys are the journal's per-tab item keys
# (element symbol, gear name, consumable / key item id); see held_keys().
const JOURNAL_TABS := ["Elements", "Equipment", "Consumables", "Key Items"]
var seen: Dictionary = {}       # tab -> { key: true } items the player has viewed
var acquired: Dictionary = {}   # "tab|key" -> stamp; higher = obtained more recently
var _stamp: int = 0
var _equip_snapshot: Dictionary = {}

static var _catalogue: Dictionary = {}

static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_catalogue = parsed
	return _catalogue

static func item_info(id: String) -> Dictionary:
	var c := catalogue()
	if c.get("consumables", {}).has(id):
		return c["consumables"][id]
	return c.get("key_items", {}).get(id, {})

# ── Ashmarks ──────────────────────────────────────────────────────────────────

func add_ashmarks(amount: int) -> void:
	ashmarks += maxi(amount, 0)
	bag_changed.emit()

func spend_ashmarks(amount: int) -> bool:
	if amount < 0 or ashmarks < amount:
		return false
	ashmarks -= amount
	bag_changed.emit()
	return true

# ── Consumables ───────────────────────────────────────────────────────────────

func add_consumable(id: String, count: int = 1) -> void:
	if not catalogue().get("consumables", {}).has(id):
		push_warning("Bag: unknown consumable '%s'" % id)
		return
	consumables[id] = mini(int(consumables.get(id, 0)) + count, STACK_MAX)
	note_acquired("Consumables", id)
	_autofill_hotbar(id)
	bag_changed.emit()

func consumable_count(id: String) -> int:
	return int(consumables.get(id, 0))

# Applies the consumable's effect to the player and uses one up.
func use_consumable(id: String) -> bool:
	if consumable_count(id) <= 0:
		return false
	var player := get_parent()
	var info: Dictionary = item_info(id)
	match str(info.get("effect", "")):
		"heal":
			if player.has_method("heal"):
				player.heal(float(info.get("amount", 0)))
		"clear_debuffs":
			if player.has_method("clear_debuffs"):
				player.clear_debuffs()
		"shield":
			if player.has_method("clear_debuffs"):
				player.clear_debuffs()
			if "_invincible_timer" in player:
				player._invincible_timer = maxf(player._invincible_timer, float(info.get("duration", 0.0)))
		_:
			return false
	consumables[id] = consumable_count(id) - 1
	if consumables[id] <= 0:
		consumables.erase(id)
		_clear_hotbar_item(id)
	bag_changed.emit()
	return true

# ── Key items ─────────────────────────────────────────────────────────────────

func add_key_item(id: String) -> void:
	if not catalogue().get("key_items", {}).has(id):
		push_warning("Bag: unknown key item '%s'" % id)
		return
	if key_items.has(id):
		return
	key_items[id] = true
	note_acquired("Key Items", id)
	bag_changed.emit()

func has_key_item(id: String) -> bool:
	return key_items.has(id)

# Combines a Boss Key from its three fragments (called by the Synthesizer).
func try_combine_boss_key(key_id: String) -> bool:
	var info: Dictionary = item_info(key_id)
	if info.get("kind", "") != "boss_key" or has_key_item(key_id):
		return false
	var frags: Array = info.get("fragments", [])
	for f in frags:
		if not has_key_item(str(f)):
			return false
	for f in frags:
		key_items.erase(str(f))
	key_items[key_id] = true
	note_acquired("Key Items", key_id)
	bag_changed.emit()
	return true

# ── Hotbar ────────────────────────────────────────────────────────────────────

func is_boss_key(id: String) -> bool:
	return str(item_info(id).get("kind", "")) == "boss_key"

# Only held consumables and held Boss Keys can go in a quick slot.
func can_assign_hotbar(id: String) -> bool:
	return consumable_count(id) > 0 or (is_boss_key(id) and has_key_item(id))

# Puts `id` in `slot` (0-based). An id lives in one slot only: if it was in
# another slot, that slot takes whatever `slot` held (a swap). "" clears.
func assign_hotbar(slot: int, id: String) -> bool:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return false
	if id != "" and not can_assign_hotbar(id):
		return false
	var old_slot: int = hotbar.find(id) if id != "" else -1
	if old_slot != -1 and old_slot != slot:
		hotbar[old_slot] = hotbar[slot]
	hotbar[slot] = id
	hotbar_changed.emit()
	return true

func hotbar_item(slot: int) -> String:
	return str(hotbar[slot]) if slot >= 0 and slot < HOTBAR_SIZE else ""

func hotbar_slot_of(id: String) -> int:
	return hotbar.find(id)

# Count shown on a slot: consumables ×N, Boss Keys 1, empty 0.
func hotbar_count(slot: int) -> int:
	var id := hotbar_item(slot)
	if id == "":
		return 0
	if consumable_count(id) > 0:
		return consumable_count(id)
	return 1 if has_key_item(id) else 0

# Uses the item in a quick slot. Returns false if the slot is empty or the item
# could not be used. The caller (Player) checks that no menu is open.
func use_hotbar(slot: int) -> bool:
	var id := hotbar_item(slot)
	if id == "":
		return false
	if consumable_count(id) > 0:
		return use_consumable(id)
	if is_boss_key(id) and has_key_item(id):
		return use_boss_key(id)
	return false

# Hook for Boss Keys used from the hotbar. For now it only announces the key
# (the HUD shows "Boss Key ready"); boss arenas will connect to
# `boss_key_requested` to open the arena and neutralise the core.
func use_boss_key(id: String) -> bool:
	if not (is_boss_key(id) and has_key_item(id)):
		return false
	boss_key_requested.emit(id)
	return true

# New consumables drop into the first empty slot if they are not on the bar yet.
func _autofill_hotbar(id: String) -> void:
	if hotbar.has(id):
		return
	var empty: int = hotbar.find("")
	if empty != -1:
		hotbar[empty] = id
		hotbar_changed.emit()

# Used-up items leave their slot empty.
func _clear_hotbar_item(id: String) -> void:
	var slot: int = hotbar.find(id)
	if slot != -1:
		hotbar[slot] = ""
		hotbar_changed.emit()

# ── Journal: "new" badges and Recent order ────────────────────────────────────

func _ready() -> void:
	var p := get_parent()
	if p == null:
		return
	var inv := p.get_node_or_null("Inventory")
	if inv and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_element_changed)
	var eq := p.get_node_or_null("Equipment")
	if eq and eq.has_signal("equipment_changed"):
		_equip_snapshot = eq.get_all()
		eq.equipment_changed.connect(_on_equipment_changed)
	var wpn := p.get_node_or_null("Weapon")
	if wpn and wpn.has_signal("weapon_changed"):
		wpn.weapon_changed.connect(func(n: String) -> void: note_acquired("Equipment", n))
	var arm := p.get_node_or_null("Armor")
	if arm and arm.has_signal("armor_changed"):
		arm.armor_changed.connect(func(n: String) -> void: note_acquired("Equipment", n))

func _on_element_changed(symbol: String, amount: float) -> void:
	if amount > 0.0:
		note_acquired("Elements", symbol)

func _on_equipment_changed() -> void:
	var eq := get_parent().get_node_or_null("Equipment")
	if eq == null:
		return
	var now: Dictionary = eq.get_all()
	for item: String in now:
		if int(now[item]) > int(_equip_snapshot.get(item, 0)):
			note_acquired("Equipment", item)
	_equip_snapshot = now

func note_acquired(tab: String, key: String) -> void:
	if key == "":
		return
	_stamp += 1
	acquired["%s|%s" % [tab, key]] = _stamp

func acquired_stamp(tab: String, key: String) -> int:
	return int(acquired.get("%s|%s" % [tab, key], 0))

# Keys of everything the journal lists on `tab` right now.
func held_keys(tab: String) -> Array:
	var p := get_parent()
	if p == null:
		return consumables.keys() if tab == "Consumables" else (key_items.keys() if tab == "Key Items" else [])
	match tab:
		"Elements":
			var inv := p.get_node_or_null("Inventory")
			return inv.get_all().keys() if inv else []
		"Equipment":
			var keys: Array = []
			var wpn := p.get_node_or_null("Weapon")
			if wpn and wpn.has_method("has_weapon") and wpn.has_weapon():
				keys.append(wpn.get_weapon_name())
			var arm := p.get_node_or_null("Armor")
			if arm and arm.has_method("has_armor") and arm.has_armor():
				keys.append(arm.get_armor_name())
			var eq := p.get_node_or_null("Equipment")
			if eq:
				keys.append_array(eq.get_all().keys())
			return keys
		"Consumables":
			return consumables.keys()
		"Key Items":
			return key_items.keys()
	return []

func is_new(tab: String, key: String) -> bool:
	return not (seen.get(tab, {}) as Dictionary).has(key)

func tab_has_new(tab: String) -> bool:
	for key in held_keys(tab):
		if is_new(tab, str(key)):
			return true
	return false

# Viewing a tab marks everything on it as seen.
func mark_tab_seen(tab: String) -> void:
	if not seen.has(tab):
		seen[tab] = {}
	for key in held_keys(tab):
		seen[tab][str(key)] = true

func mark_all_seen() -> void:
	for tab: String in JOURNAL_TABS:
		mark_tab_seen(tab)

# ── Save ──────────────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var seen_out: Dictionary = {}
	for tab: String in seen:
		seen_out[tab] = (seen[tab] as Dictionary).keys()
	return { "ashmarks": ashmarks, "consumables": consumables.duplicate(), "key_items": key_items.keys(),
		"hotbar": hotbar.duplicate(), "seen": seen_out, "acquired": acquired.duplicate(), "stamp": _stamp }

func deserialize(d: Dictionary) -> void:
	ashmarks = int(d.get("ashmarks", 0))
	consumables.clear()
	var cons: Dictionary = d.get("consumables", {})
	for id in cons:
		consumables[str(id)] = int(cons[id])
	key_items.clear()
	for id in d.get("key_items", []):
		key_items[str(id)] = true
	# Quick slots, "new" badges and Recent order (absent in older saves).
	hotbar = ["", "", "", ""]
	var saved_bar: Array = d.get("hotbar", []) as Array
	for i: int in mini(saved_bar.size(), HOTBAR_SIZE):
		var id: String = str(saved_bar[i]) if saved_bar[i] != null else ""
		hotbar[i] = id if id == "" or can_assign_hotbar(id) else ""
	if not d.has("hotbar"):
		for id: String in consumables:
			_autofill_hotbar(id)
	acquired.clear()
	var acq: Dictionary = d.get("acquired", {}) as Dictionary
	for k in acq:
		acquired[str(k)] = int(acq[k])
	_stamp = int(d.get("stamp", 0))
	seen.clear()
	if d.has("seen"):
		var seen_in: Dictionary = d.get("seen", {}) as Dictionary
		for tab in seen_in:
			seen[str(tab)] = {}
			for key in seen_in[tab]:
				seen[str(tab)][str(key)] = true
	else:
		# Older save: don't flood the journal with "new" marks for old items.
		# Deferred so the rest of the player (loaded before the Bag) is in place.
		call_deferred("mark_all_seen")
	var eq := get_parent().get_node_or_null("Equipment") if get_parent() else null
	if eq:
		_equip_snapshot = eq.get_all()
	hotbar_changed.emit()
	bag_changed.emit()
