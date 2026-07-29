extends Node

# ResonanceSystem — tracks Act 3 endgame progress: the six Resonance Engine
# components and their final assembly by Prof. Aldric Daedalus.
#
# Autoload as "ResonanceSystem".
#
# Component definitions are read from compounds.json (category
# "resonance_engine_part") rather than hardcoded, so adding, removing, or
# reordering components is a pure data change with no code edit.
#
# Flow:
#   1. Player crafts each of the 6 components in the 3x3 grid.
#   2. Crafted components are stored in Equipment.items by their game_item key.
#   3. When all 6 are held, `engine_ready` fires and the HUD prompts the
#      player to bring them to Aldric.
#   4. Interacting with Aldric consumes the components and assembles the
#      Resonance Engine — the game's win condition.

signal part_acquired(item_key: String, collected: int, total: int)
signal engine_ready
signal engine_assembled(engine_name: String)

const PART_CATEGORY: String   = "resonance_engine_part"
const ENGINE_CATEGORY: String = "story_device"
const ENGINE_ITEM: String     = "resonance_engine"

var is_assembled: bool = false

var _ready_announced: bool = false

# ── Data access ───────────────────────────────────────────────────────────────

# All compound definitions that make up the engine, ordered by story act.
func get_part_compounds() -> Array:
	var parts: Array = []
	for c: Dictionary in ElementDB.compounds.values():
		if str(c.get("category", "")) == PART_CATEGORY:
			parts.append(c)
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var act_a: int = int(a.get("act", 0))
		var act_b: int = int(b.get("act", 0))
		if act_a != act_b:
			return act_a < act_b
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return parts

func get_part_keys() -> Array:
	var keys: Array = []
	for c: Dictionary in get_part_compounds():
		var key: String = str(c.get("game_item", ""))
		if key != "":
			keys.append(key)
	return keys

func get_engine_compound() -> Dictionary:
	for c: Dictionary in ElementDB.compounds.values():
		if str(c.get("category", "")) == ENGINE_CATEGORY \
		and str(c.get("game_item", "")) == ENGINE_ITEM:
			return c
	return {}

func total_parts() -> int:
	return get_part_keys().size()

func is_part(item_key: String) -> bool:
	return item_key in get_part_keys()

func display_name_for(item_key: String) -> String:
	for c: Dictionary in get_part_compounds():
		if str(c.get("game_item", "")) == item_key:
			return str(c.get("name", item_key))
	return item_key

# ── Progress queries ──────────────────────────────────────────────────────────

func collected_parts(equipment: Node) -> Array:
	var held: Array = []
	if equipment == null:
		return held
	for key: String in get_part_keys():
		if int(equipment.items.get(key, 0)) > 0:
			held.append(key)
	return held

func missing_parts(equipment: Node) -> Array:
	var missing: Array = []
	if equipment == null:
		return missing
	for key: String in get_part_keys():
		if int(equipment.items.get(key, 0)) <= 0:
			missing.append(key)
	return missing

func has_all_parts(equipment: Node) -> bool:
	if equipment == null:
		return false
	return missing_parts(equipment).is_empty() and total_parts() > 0

# Call after a component is crafted so progress signals fire.
func notify_part_crafted(item_key: String, equipment: Node) -> void:
	if not is_part(item_key):
		return
	var collected: int = collected_parts(equipment).size()
	emit_signal("part_acquired", item_key, collected, total_parts())
	if not _ready_announced and has_all_parts(equipment):
		_ready_announced = true
		emit_signal("engine_ready")

# ── Assembly ──────────────────────────────────────────────────────────────────

# Consumes all six components and assembles the engine.
# Returns the engine compound dict on success, {} on failure.
func assemble(equipment: Node) -> Dictionary:
	if is_assembled or not has_all_parts(equipment):
		return {}
	for key: String in get_part_keys():
		var remaining: int = int(equipment.items.get(key, 0)) - 1
		if remaining > 0:
			equipment.items[key] = remaining
		else:
			equipment.items.erase(key)
	var engine: Dictionary = get_engine_compound()
	var engine_key: String = str(engine.get("game_item", ENGINE_ITEM))
	equipment.items[engine_key] = 1
	equipment.emit_signal("equipment_changed")
	is_assembled = true
	emit_signal("engine_assembled", str(engine.get("name", "Resonance Engine")))
	return engine

# ── Persistence ───────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return { "is_assembled": is_assembled, "ready_announced": _ready_announced }

func deserialize(data: Dictionary) -> void:
	is_assembled = bool(data.get("is_assembled", false))
	_ready_announced = bool(data.get("ready_announced", false))

func reset() -> void:
	is_assembled = false
	_ready_announced = false
