extends Node

# ElementDatabase — loads and provides access to all element and compound data.
# Autoload this as "ElementDB" in Project > Project Settings > Autoload.

var elements: Dictionary = {}
var compounds: Dictionary = {}          # { "steel_sword": {...} } keyed by game_item
var compounds_by_formula: Dictionary = {}  # { "Fe·C": {...} } first match wins
var handling: Dictionary = {}  # { "Fe": { container, handling, hazards } }
var enemies: Dictionary = {}   # { "ashburn_shambler": {...}, ... }
var enemy_tier_multipliers: Dictionary = {}

# Maps container/handling keys to the in-game item name the player must carry
const CONTAINER_ITEMS := {
	"standard_vial":        "Standard Vial",
	"glass_vial":           "Glass Vial",
	"sealed_ampule":        "Sealed Ampule",
	"pressurized_canister": "Pressure Canister",
	"inert_container":      "Inert Container",
	"lead_container":       "Lead Container",
}
const HANDLING_ITEMS := {
	"standard":       "",               # no equipment needed
	"nitrile_gloves": "Nitrile Gloves",
	"heavy_gloves":   "Heavy Gloves",
	"glove_box":      "Glove Box Kit",
	"radiation_suit": "Radiation Suit",
}

func _ready() -> void:
	_load_elements()
	_load_compounds()
	_load_handling()
	_load_enemies()

func _load_elements() -> void:
	var file := FileAccess.open("res://data/elements.json", FileAccess.READ)
	if file == null:
		push_error("ElementDB: could not open elements.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDB: failed to parse elements.json")
		return
	for el: Dictionary in (json.data as Array):
		elements[el["symbol"]] = el

func _load_compounds() -> void:
	var file := FileAccess.open("res://data/compounds.json", FileAccess.READ)
	if file == null:
		push_error("ElementDB: could not open compounds.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDB: failed to parse compounds.json")
		return
	for compound: Dictionary in (json.data as Array):
		# Keyed by game_item, not formula: several distinct recipes legitimately
		# share a formula (e.g. Steel / Steel Sword are both "Fe·C"), and keying
		# by formula silently discarded five compounds — including the Uranium
		# Fuel Cell, which made the Act 3 endgame unobtainable.
		var item_key: String = str(compound.get("game_item", ""))
		if item_key == "":
			push_warning("ElementDB: compound '%s' has no game_item, skipping"
				% str(compound.get("name", "?")))
			continue
		if compounds.has(item_key):
			push_warning("ElementDB: duplicate game_item '%s' — overwriting" % item_key)
		compounds[item_key] = compound
		var formula: String = str(compound.get("formula", ""))
		if formula != "" and not compounds_by_formula.has(formula):
			compounds_by_formula[formula] = compound

func _load_handling() -> void:
	var file := FileAccess.open("res://data/element_handling.json", FileAccess.READ)
	if file == null:
		push_error("ElementDB: could not open element_handling.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDB: failed to parse element_handling.json")
		return
	for entry: Dictionary in (json.data as Array):
		handling[str(entry["symbol"])] = entry

# JSON `null` survives parsing as a nil Variant. Dictionary.get(key, default)
# only returns the default when the key is *missing*, so a key present with a
# null value yields nil and breaks strictly-typed reads such as
# `var s: String = data.get("aura", "")`. Normalise nulls to "" at load time.
static func sanitize_nulls(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in (value as Dictionary):
				out[key] = sanitize_nulls((value as Dictionary)[key])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item: Variant in (value as Array):
				arr.append(sanitize_nulls(item))
			return arr
		TYPE_NIL:
			return ""
		_:
			return value

func get_element(symbol: String) -> Dictionary:
	return elements.get(symbol, {})

func get_compound(formula: String) -> Dictionary:
	return compounds_by_formula.get(formula, {})

func get_compound_by_item(item_key: String) -> Dictionary:
	return compounds.get(item_key, {})

# Recipes that share an identical ingredient map (e.g. Bronze and Bronze Sword
# are both Cu×3 + Sn) are resolved by this precedence so crafting is
# deterministic rather than dependent on dictionary iteration order.
# Higher rank wins; ties fall back to alphabetical name for stability.
const CATEGORY_PRECEDENCE := {
	"story_device":          100,
	"resonance_engine_part":  90,
	"armor":                  80,
	"weapon_melee":           70,
	"weapon_ranged":          70,
	"polymer":                60,
	"medicine":               50,
	"consumable":             50,
}

func _recipe_rank(c: Dictionary) -> int:
	return int(CATEGORY_PRECEDENCE.get(str(c.get("category", "")), 10))

# Ingredient counts arrive from two sources with different numeric types:
# JSON recipe data parses counts as FLOAT, while the crafting grid tallies
# them as INT. Dictionary `==` is type-strict, so a direct comparison never
# matched and no recipe was craftable. Compare numerically instead.
func _ingredients_match(recipe: Dictionary, provided: Dictionary) -> bool:
	if recipe.size() != provided.size():
		return false
	for key: Variant in recipe:
		if not provided.has(key):
			return false
		if not is_equal_approx(float(recipe[key]), float(provided[key])):
			return false
	return true

# Given a dict of {symbol: count}, find the matching compound if one exists.
func match_recipe(ingredient_map: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_rank: int = -1
	for item_key: String in compounds:
		var c: Dictionary = compounds[item_key]
		if not _ingredients_match(c.get("elements", {}) as Dictionary, ingredient_map):
			continue
		var rank: int = _recipe_rank(c)
		if rank > best_rank \
		or (rank == best_rank and str(c.get("name", "")) < str(best.get("name", ""))):
			best = c
			best_rank = rank
	return best

# Returns { "container_item": String, "handling_item": String, "hazards": Array }
# container_item / handling_item are "" if no special equipment needed
func get_handling(symbol: String) -> Dictionary:
	var h: Dictionary = handling.get(symbol, {})
	if h.is_empty():
		return { "container_item": "Standard Vial", "handling_item": "", "hazards": [] }
	var container_item: String = CONTAINER_ITEMS.get(str(h.get("container", "standard_vial")), "Standard Vial")
	var handling_item: String  = HANDLING_ITEMS.get(str(h.get("handling", "standard")), "")
	return {
		"container_item": container_item,
		"handling_item":  handling_item,
		"hazards":        h.get("hazards", []),
	}

func _load_enemies() -> void:
	var file := FileAccess.open("res://data/enemy_data.json", FileAccess.READ)
	if file == null:
		push_error("ElementDB: could not open enemy_data.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDB: failed to parse enemy_data.json")
		return
	var data: Dictionary = json.data as Dictionary
	enemy_tier_multipliers = data.get("tier_multipliers", {})
	for c: Dictionary in (data.get("creatures", []) as Array):
		enemies[str(c.get("id", ""))] = sanitize_nulls(c)

func get_enemy_data(creature_id: String) -> Dictionary:
	return enemies.get(creature_id, {})

func get_enemy_tier_mult(tier: String) -> Dictionary:
	return enemy_tier_multipliers.get(tier, { "hp": 1.0, "damage": 1.0, "speed": 1.0, "sight": 1.0 })

func get_elements_by_biome(biome: String) -> Array:
	var result: Array = []
	for symbol: String in elements:
		if elements[symbol].get("biome") == biome:
			result.append(elements[symbol])
	return result

func get_elements_by_category(category: String) -> Array:
	var result: Array = []
	for symbol: String in elements:
		if elements[symbol].get("category") == category:
			result.append(elements[symbol])
	return result
