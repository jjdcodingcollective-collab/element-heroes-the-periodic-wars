extends Node

# Inventory — tracks element quantities the player is carrying.
# Attach to the Player node as a child named "Inventory".

signal inventory_changed(symbol: String, amount: int)

var elements: Dictionary = {}  # { "Fe": 3, "Na": 1, ... }
const MAX_STACK: int = 999

func add_element(symbol: String, amount: int = 1) -> void:
	elements[symbol] = min(elements.get(symbol, 0) + amount, MAX_STACK)
	emit_signal("inventory_changed", symbol, elements[symbol])

func remove_element(symbol: String, amount: int = 1) -> bool:
	if not has_element(symbol, amount):
		return false
	elements[symbol] -= amount
	if elements[symbol] <= 0:
		elements.erase(symbol)
	emit_signal("inventory_changed", symbol, elements.get(symbol, 0))
	return true

func has_element(symbol: String, amount: int = 1) -> bool:
	return elements.get(symbol, 0) >= amount

func has_elements(required: Dictionary) -> bool:
	for symbol in required:
		if not has_element(symbol, required[symbol]):
			return false
	return true

func remove_elements(required: Dictionary) -> bool:
	if not has_elements(required):
		return false
	for symbol in required:
		remove_element(symbol, required[symbol])
	return true

func get_count(symbol: String) -> int:
	return elements.get(symbol, 0)

func get_all() -> Dictionary:
	return elements.duplicate()

func clear() -> void:
	elements.clear()

func serialize() -> Dictionary:
	return elements.duplicate()

func deserialize(data: Dictionary) -> void:
	elements = data.duplicate()
