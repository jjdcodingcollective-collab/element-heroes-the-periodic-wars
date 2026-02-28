extends Control

# CompendiumUI — in-game periodic table reference.
# Shows all 118 elements; discovered ones are highlighted.

@onready var element_grid: GridContainer = $ElementGrid
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_name: Label = $DetailPanel/VBox/Name
@onready var detail_symbol: Label = $DetailPanel/VBox/Symbol
@onready var detail_mass: Label = $DetailPanel/VBox/Mass
@onready var detail_category: Label = $DetailPanel/VBox/Category
@onready var detail_biome: Label = $DetailPanel/VBox/Biome
@onready var detail_fact: Label = $DetailPanel/VBox/FunFact

var discovered: Dictionary = {}  # { "Fe": true, ... }

func _ready() -> void:
	_build_grid()
	detail_panel.hide()

func _build_grid() -> void:
	for child in element_grid.get_children():
		child.queue_free()

	# Sort elements by atomic number
	var all_elements = ElementDB.elements.values()
	all_elements.sort_custom(func(a, b): return a["atomic_number"] < b["atomic_number"])

	for el in all_elements:
		var btn = Button.new()
		btn.text = el["symbol"]
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = el["name"]

		if discovered.get(el["symbol"], false):
			btn.modulate = _category_color(el.get("category", ""))
		else:
			btn.modulate = Color(0.2, 0.2, 0.2)  # undiscovered = dark

		btn.pressed.connect(_on_element_pressed.bind(el["symbol"]))
		element_grid.add_child(btn)

func _on_element_pressed(symbol: String) -> void:
	var el = ElementDB.get_element(symbol)
	if el.is_empty():
		return
	detail_name.text = el.get("name", "")
	detail_symbol.text = el.get("symbol", "")
	detail_mass.text = "Atomic Mass: %.2f" % el.get("mass", 0.0)
	detail_category.text = el.get("category", "").replace("_", " ").capitalize()
	detail_biome.text = "Found in: %s" % el.get("biome", "unknown").replace("_", " ").capitalize()
	detail_fact.text = el.get("fun_fact", "")
	detail_panel.show()

func mark_discovered(symbol: String) -> void:
	discovered[symbol] = true
	_build_grid()  # rebuild to update colors

func _category_color(category: String) -> Color:
	match category:
		"alkali_metal":       return Color(1.0, 0.4, 0.4)
		"alkaline_earth":     return Color(1.0, 0.7, 0.4)
		"transition_metal":   return Color(1.0, 0.9, 0.4)
		"post_transition":    return Color(0.6, 0.9, 0.4)
		"metalloid":          return Color(0.4, 0.9, 0.7)
		"nonmetal":           return Color(0.4, 0.7, 1.0)
		"halogen":            return Color(0.7, 0.4, 1.0)
		"noble_gas":          return Color(1.0, 0.4, 0.9)
		"lanthanide":         return Color(1.0, 0.6, 0.6)
		"actinide":           return Color(0.8, 0.4, 0.4)
		_:                    return Color(0.7, 0.7, 0.7)
