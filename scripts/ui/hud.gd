extends CanvasLayer

# HUD — top-level in-game UI. Manages minimap, inventory bar, biome label,
# health bar, and dialogue box.

@onready var minimap: Control         = $Minimap
@onready var inventory_bar: Control   = $InventoryBar
@onready var inv_label: Label         = $InventoryBar/Label
@onready var biome_label: Label       = $BiomeLabel
@onready var dialogue_ui: CanvasLayer = $DialogueUI
@onready var health_bar: Control      = $HealthBar
@onready var health_fill: ColorRect   = $HealthBar/Fill
@onready var health_label: Label      = $HealthBar/HPLabel

var _player: Node = null
var _world: Node = null
var _biome_timer: float = 0.0
var _inv_timer: float = 0.0

func _ready() -> void:
	add_to_group("ui")
	dialogue_ui.add_to_group("dialogue_ui")
	var compendium := get_node_or_null("Compendium")
	if compendium:
		compendium.add_to_group("compendium")

func init(player: Node, world: Node) -> void:
	_player = player
	_world = world
	minimap.player_ref = player
	var inv := player.get_node_or_null("Inventory")
	if inv:
		inv.inventory_changed.connect(_on_inventory_changed)
	var equip := player.get_node_or_null("Equipment")
	if equip:
		equip.equipment_changed.connect(_on_inventory_changed.bind("", 0.0))
	_refresh_inventory_bar()

func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	# Biome label — update every 0.5s
	_biome_timer += delta
	if _biome_timer >= 0.5:
		_biome_timer = 0.0
		var biome: String = _world.get_biome_at((_player as Node2D).global_position)
		biome_label.text = biome.replace("_", " ").capitalize()
	# Health bar
	if _player.has_method("get_health"):
		var hp: float = float(_player.get_health())
		var max_hp: float = float(_player.get_max_health())
		health_fill.size.x = 80.0 * (hp / max_hp)
		health_label.text = "%d/%d HP" % [int(hp), int(max_hp)]

func _on_inventory_changed(_symbol: String, _amount: float) -> void:
	_refresh_inventory_bar()

func _refresh_inventory_bar() -> void:
	if _player == null:
		return
	var inv := _player.get_node_or_null("Inventory")
	if inv == null:
		return
	var all: Dictionary = inv.get_all()
	var parts: Array = []
	# Elements
	for symbol: String in all:
		var amount: float = float(all[symbol])
		var unit: String = inv.unit_for(symbol)
		parts.append("%s:%.2f%s" % [symbol, amount, unit])
	# Equipment (show containers count + worn items)
	var equip := _player.get_node_or_null("Equipment")
	if equip:
		var eq_all: Dictionary = equip.get_all()
		for item: String in eq_all:
			var count: int = int(eq_all[item])
			if item in equip.REUSABLE:
				parts.append("[%s]" % item)
			else:
				parts.append("%s×%d" % [item.left(4), count])
	if parts.is_empty():
		inv_label.text = "Inventory empty  |  E to toggle"
	else:
		inv_label.text = "  ".join(parts)

func toggle_inventory() -> void:
	inventory_bar.visible = not inventory_bar.visible

func toggle_compendium() -> void:
	var compendium := $Compendium
	if compendium:
		compendium.visible = not compendium.visible

func toggle_crafting() -> void:
	# CraftingUI is a sibling CanvasLayer instanced into world.tscn
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.visible = not crafting.visible

func set_crafting_inventory(inv: Node) -> void:
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.player_inventory = inv
