## ElementDatabase.gd
## Autoload singleton — access via ElementDatabase.get_element("Fe")
extends Node

var elements: Dictionary = {}
var compounds: Dictionary = {}

func _ready() -> void:
	_load_elements()
	_load_compounds()

func _load_elements() -> void:
	var file = FileAccess.open("res://data/elements/elements.json", FileAccess.READ)
	if not file:
		push_error("ElementDatabase: Could not load elements.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDatabase: Failed to parse elements.json")
		return
	for element in json.data:
		elements[element["symbol"]] = element
	print("ElementDatabase: Loaded %d elements" % elements.size())

func _load_compounds() -> void:
	var file = FileAccess.open("res://data/compounds/compounds.json", FileAccess.READ)
	if not file:
		push_error("ElementDatabase: Could not load compounds.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ElementDatabase: Failed to parse compounds.json")
		return
	for compound in json.data:
		compounds[compound["id"]] = compound
	print("ElementDatabase: Loaded %d compounds" % compounds.size())

func get_element(symbol: String) -> Dictionary:
	return elements.get(symbol, {})

func get_compound(id: String) -> Dictionary:
	return compounds.get(id, {})

func get_elements_by_biome(biome: String) -> Array:
	return elements.values().filter(func(e): return e["biome"] == biome)

func get_elements_by_category(category: String) -> Array:
	return elements.values().filter(func(e): return e["category"] == category)

## Given a dictionary of { symbol: count }, find matching compound recipes.
## Returns an Array of matching compound dictionaries.
func find_matching_compounds(input: Dictionary) -> Array:
	var matches = []
	for compound in compounds.values():
		if compound["elements"] == input:
			matches.append(compound)
	return matches

## Fuzzy match — returns compounds where input elements are a subset of the recipe
func find_possible_compounds(input_symbols: Array) -> Array:
	var possible = []
	for compound in compounds.values():
		var recipe_symbols = compound["elements"].keys()
		var all_present = true
		for symbol in recipe_symbols:
			if symbol not in input_symbols:
				all_present = false
				break
		if all_present:
			possible.append(compound)
	return possible
