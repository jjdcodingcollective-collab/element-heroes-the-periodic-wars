extends Node

# CraftingSystem — validates crafting grid input against compound recipes.
# Autoload as "CraftingSystem" or attach to a crafting UI node.

const GRID_SIZE: int = 3

# grid_contents: 3x3 Array of element symbols (or "" for empty)
# Returns the matched compound dict, or {} if no match.
func evaluate_grid(grid_contents: Array) -> Dictionary:
	var ingredient_map: Dictionary = _grid_to_ingredient_map(grid_contents)
	if ingredient_map.is_empty():
		return {}
	return ElementDB.match_recipe(ingredient_map)

func _grid_to_ingredient_map(grid: Array) -> Dictionary:
	var counts: Dictionary = {}
	for row: Array in grid:
		for cell: String in row:
			if cell != "":
				counts[cell] = counts.get(cell, 0) + 1
	return counts

# Attempt to craft using the player's inventory.
# Returns the compound dict on success, {} on failure.
func try_craft(grid_contents: Array, inventory: Node) -> Dictionary:
	var compound: Dictionary = evaluate_grid(grid_contents)
	if compound.is_empty():
		return {}

	var required: Dictionary = compound.get("elements", {}) as Dictionary
	# Convert keys to strings and values to floats (JSON may parse as int)
	var required_str: Dictionary = {}
	for k: Variant in required:
		required_str[str(k)] = float(required[k])

	if inventory.remove_elements(required_str):
		return compound
	return {}
