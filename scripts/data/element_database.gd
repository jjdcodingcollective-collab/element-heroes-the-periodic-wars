extends Node

# ElementDatabase — loads and provides access to all element and compound data.
# Autoload this as "ElementDB" in Project > Project Settings > Autoload.

var elements: Dictionary = {}
var compounds: Dictionary = {}

func _ready() -> void:
	_load_elements()
	_load_compounds()

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
