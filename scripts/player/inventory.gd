extends Node

# Inventory — tracks element quantities in grams (solids) or millilitres (liquids/gases).
# Amounts are floats rounded to 2 decimal places for display.

signal inventory_changed(symbol: String, amount: float)

var elements: Dictionary = {}  # { "Fe": 3.5, "Na": 1.2, ... }
const MAX_AMOUNT: float = 9999.0

func add_element(symbol: String, amount: float = 1.0) -> void:
	var current: float = float(elements.get(symbol, 0.0))
	elements[symbol] = minf(current + amount, MAX_AMOUNT)
	emit_signal("inventory_changed", symbol, elements[symbol])

func remove_element(symbol: String, amount: float) -> bool:
	if not has_element(symbol, amount):
		return false
	elements[symbol] = float(elements[symbol]) - amount
	if float(elements[symbol]) <= 0.0:
		elements.erase(symbol)
	emit_signal("inventory_changed", symbol, elements.get(symbol, 0.0))
	return true

func has_element(symbol: String, amount: float = 0.001) -> bool:
	return float(elements.get(symbol, 0.0)) >= amount

func has_elements(required: Dictionary) -> bool:
	for symbol: String in required:
		if not has_element(symbol, float(required[symbol])):
			return false
	return true

func remove_elements(required: Dictionary) -> bool:
	if not has_elements(required):
		return false
	for symbol: String in required:
		remove_element(symbol, float(required[symbol]))
	return true

func get_amount(symbol: String) -> float:
	return float(elements.get(symbol, 0.0))

func get_all() -> Dictionary:
	return elements.duplicate()

func clear() -> void:
	elements.clear()

func serialize() -> Dictionary:
	return elements.duplicate()

func deserialize(data: Dictionary) -> void:
	elements = data.duplicate()

# Returns display string: "1.50g" for solids, "0.80mL" for liquids/gases
static func format_amount(symbol: String, amount: float) -> String:
	var el: Dictionary = ElementDB.get_element(symbol)
	var state: String = str(el.get("state", "solid"))
	var unit: String = "mL" if state in ["liquid", "gas"] else "g"
	return "%.2f%s" % [amount, unit]

# Returns the unit label for an element
static func unit_for(symbol: String) -> String:
	var el: Dictionary = ElementDB.get_element(symbol)
	var state: String = str(el.get("state", "solid"))
	return "mL" if state in ["liquid", "gas"] else "g"
