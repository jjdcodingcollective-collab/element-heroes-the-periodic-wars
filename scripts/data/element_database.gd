extends Node

# ElementDatabase — loads and provides access to all element and compound data.
# Autoload this as "ElementDB" in Project > Project Settings > Autoload.

var elements: Dictionary = {}
var compounds: Dictionary = {}
var handling: Dictionary = {}  # { "Fe": { container, handling, hazards } }

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
		compounds[compound["formula"]] = compound

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

func get_element(symbol: String) -> Dictionary:
	return elements.get(symbol, {})

func get_compound(formula: String) -> Dictionary:
	return compounds.get(formula, {})

# Given a dict of {symbol: count}, find a matching compound if one exists.
func match_recipe(ingredient_map: Dictionary) -> Dictionary:
	for formula: String in compounds:
		var c: Dictionary = compounds[formula]
		if c["elements"] == ingredient_map:
			return c
	return {}

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
