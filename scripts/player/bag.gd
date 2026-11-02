extends Node

# Bag — Ashmarks (currency), consumables and key items. Child "Bag" of Player.
# Elements live in Inventory and lab gear in Equipment; this holds everything
# else the inventory screen shows on its Consumables and Key Items tabs.
#
# Key items (Key Fragments, Boss Keys) are permanent: once earned they are never
# removed, except fragments, which are absorbed when combined into their Boss Key.
# Item definitions: data/items.json.

signal bag_changed

const ITEMS_PATH := "res://data/items.json"

var ashmarks: int = 0
var consumables: Dictionary = {}   # id -> count
var key_items: Dictionary = {}     # id -> true

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
	consumables[id] = int(consumables.get(id, 0)) + count
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
	bag_changed.emit()
	return true

# ── Save ──────────────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return { "ashmarks": ashmarks, "consumables": consumables.duplicate(), "key_items": key_items.keys() }

func deserialize(d: Dictionary) -> void:
	ashmarks = int(d.get("ashmarks", 0))
	consumables.clear()
	var cons: Dictionary = d.get("consumables", {})
	for id in cons:
		consumables[str(id)] = int(cons[id])
	key_items.clear()
	for id in d.get("key_items", []):
		key_items[str(id)] = true
	bag_changed.emit()
