## CraftingSystem.gd
## Attach to the crafting bench scene. Handles recipe validation and crafting.
extends Node

## Reference to the player (set by parent scene)
@export var player: CharacterBody2D

## Current grid input: slot index (0-8) -> element symbol string
var grid: Array = ["", "", "", "", "", "", "", "", ""]  # 3x3 = 9 slots

signal craft_success(compound: Dictionary)
signal craft_failure(reason: String)
signal grid_changed()

# ── Grid Management ────────────────────────────────────────────────────────────

func set_slot(index: int, symbol: String) -> void:
	if index < 0 or index >= 9:
		return
	grid[index] = symbol
	emit_signal("grid_changed")

func clear_slot(index: int) -> void:
	set_slot(index, "")

func clear_grid() -> void:
	grid = ["", "", "", "", "", "", "", "", ""]
	emit_signal("grid_changed")

func get_grid_elements() -> Dictionary:
	## Returns a count dict of elements in the grid: { "Fe": 2, "C": 1 }
	var counts: Dictionary = {}
	for symbol in grid:
		if symbol != "":
			counts[symbol] = counts.get(symbol, 0) + 1
	return counts

# ── Recipe Matching ────────────────────────────────────────────────────────────

func get_current_result() -> Dictionary:
	## Returns the matching compound, or empty dict if no match.
	var input = get_grid_elements()
	if input.is_empty():
		return {}
	var matches = ElementDatabase.find_matching_compounds(input)
	if matches.is_empty():
		return {}
	return matches[0]

func get_possible_results() -> Array:
	## Fuzzy: what could be made with elements currently in grid?
	var symbols = get_grid_elements().keys()
	return ElementDatabase.find_possible_compounds(symbols)

# ── Crafting ───────────────────────────────────────────────────────────────────

func attempt_craft() -> void:
	var result = get_current_result()
	if result.is_empty():
		emit_signal("craft_failure", "No valid compound found for these elements.")
		return

	var required = result["elements"]

	if not player:
		emit_signal("craft_failure", "No player assigned to crafting system.")
		return

	if not player.consume_elements(required):
		emit_signal("craft_failure", "Not enough elements in inventory.")
		return

	clear_grid()
	emit_signal("craft_success", result)
	print("Crafted: %s (%s)" % [result["name"], result["formula"]])
