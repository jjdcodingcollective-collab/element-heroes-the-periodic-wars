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
	add_to_group("hud")
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
		# Compendium discovery hook: mark element when first collected
		inv.inventory_changed.connect(_on_element_discovered)
	var equip := player.get_node_or_null("Equipment")
	if equip:
		equip.equipment_changed.connect(_on_inventory_changed.bind("", 0.0))
	var wpn := player.get_node_or_null("Weapon")
	if wpn:
		wpn.weapon_changed.connect(_on_weapon_changed)
	var arm := player.get_node_or_null("Armor")
	if arm:
		arm.armor_changed.connect(_on_armor_changed)
	var bag := player.get_node_or_null("Bag")
	if bag:
		bag.bag_changed.connect(_refresh_inventory_bar)
	_refresh_inventory_bar()

var _last_biome: String = ""

func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	# Biome label — update every 0.5s
	_biome_timer += delta
	if _biome_timer >= 0.5:
		_biome_timer = 0.0
		var biome: String = _world.get_biome_at((_player as Node2D).global_position)
		biome_label.text = biome.replace("_", " ").capitalize()
		if biome != _last_biome:
			_last_biome = biome
			AudioManager.on_biome_changed(biome)
	# Health bar
	if _player.has_method("get_health"):
		var hp: float = float(_player.get_health())
		var max_hp: float = float(_player.get_max_health())
		health_fill.size.x = 80.0 * (hp / max_hp)
		health_label.text = "%d/%d HP" % [int(hp), int(max_hp)]

func _on_inventory_changed(_symbol: String, _amount: float) -> void:
	_refresh_inventory_bar()

func _on_element_discovered(symbol: String, _amount: float) -> void:
	var compendium := get_node_or_null("Compendium")
	if compendium and compendium.has_method("mark_discovered"):
		compendium.mark_discovered(symbol)

func _on_weapon_changed(_weapon_name: String) -> void:
	_refresh_inventory_bar()

func _on_armor_changed(_armor_name: String) -> void:
	_refresh_inventory_bar()

func _refresh_inventory_bar() -> void:
	if _player == null:
		return
	var inv := _player.get_node_or_null("Inventory")
	if inv == null:
		return
	var all: Dictionary = inv.get_all()
	var parts: Array = []
	var bag := _player.get_node_or_null("Bag")
	if bag:
		parts.append("◈ %d Ashmarks" % bag.ashmarks)
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
	# Equipped weapon
	var wpn := _player.get_node_or_null("Weapon")
	if wpn and wpn.has_method("has_weapon") and wpn.has_weapon():
		parts.append("⚔ %s" % wpn.get_weapon_name().replace("_", " "))

	# Equipped armor
	var arm := _player.get_node_or_null("Armor")
	if arm and arm.has_method("has_armor") and arm.has_armor():
		var dr_pct: int = int(arm.get_damage_reduction() * 100.0)
		parts.append("🛡 %s (%d%%)" % [arm.get_armor_name().replace("_", " "), dr_pct])

	if parts.is_empty():
		inv_label.text = "Inventory empty  |  E: inventory"
	else:
		inv_label.text = "  ".join(parts)

func toggle_inventory() -> void:
	inventory_bar.visible = not inventory_bar.visible

func toggle_compendium() -> void:
	var compendium := $Compendium
	if compendium:
		compendium.visible = not compendium.visible
		_play_toggle_sfx(compendium.visible)

func toggle_crafting() -> void:
	# CraftingUI is a sibling CanvasLayer instanced into world.tscn
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.visible = not crafting.visible
		_play_toggle_sfx(crafting.visible)

func _play_toggle_sfx(opened: bool) -> void:
	if opened:
		AudioManager.on_ui_open()
	else:
		AudioManager.on_ui_close()

func set_crafting_inventory(inv: Node) -> void:
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.player_inventory = inv

func show_lore(boss_name: String, lore_text: String) -> void:
	var label := Label.new()
	label.text = "[%s]\n%s" % [boss_name, lore_text]
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.9, 0.85, 0.5)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	label.z_index = 200

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	style.border_color = Color(0.9, 0.85, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.anchor_bottom = 1.0
	panel.anchor_left   = 0.0
	panel.offset_left   = 16.0
	panel.offset_bottom = -16.0
	panel.z_index = 200
	add_child(panel)

	var tween := get_tree().create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.5)
	tween.tween_callback(panel.queue_free).set_delay(1.5)

# ── Death / Victory overlays ─────────────────────────────────────────────────

signal respawn_requested

var _death_overlay: Control = null
var _death_input_armed: bool = false

const DEATH_QUOTES := [
	"\"Every failed reaction is data, Orion. Get up.\"  — Prof. Aldric Daedalus",
	"\"Conservation of mass says nothing about conservation of pride.\"  — Prof. Aldric Daedalus",
	"\"You are not destroyed. You are merely... rearranged.\"  — Prof. Aldric Daedalus",
	"\"The wilds test hypotheses harshly. Revise and return.\"  — Prof. Aldric Daedalus",
]

func show_death_screen() -> void:
	if _death_overlay != null:
		return
	_death_input_armed = false

	_death_overlay = Control.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_overlay.z_index = 300
	add_child(_death_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.0, 0.02, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_death_overlay.add_child(vbox)

	var title := Label.new()
	title.text = "REACTION FAILED"
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(0.95, 0.25, 0.25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var quote := Label.new()
	quote.text = DEATH_QUOTES[randi() % DEATH_QUOTES.size()]
	quote.add_theme_font_size_override("font_size", 12)
	quote.modulate = Color(0.8, 0.8, 0.7)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(quote)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = ""
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.9, 0.85, 0.4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var keep := Label.new()
	keep.text = "Your samples and equipment are intact."
	keep.add_theme_font_size_override("font_size", 10)
	keep.modulate = Color(0.6, 0.75, 0.6)
	keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(keep)

	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.88, 0.8)
	tween.tween_callback(func() -> void:
		_death_input_armed = true
		hint.text = "Press any key to wake in Ashvale"
	)

func _input(event: InputEvent) -> void:
	if _death_overlay == null or not _death_input_armed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss_death_screen()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_dismiss_death_screen()
		get_viewport().set_input_as_handled()

func _dismiss_death_screen() -> void:
	_death_input_armed = false
	if _death_overlay:
		_death_overlay.queue_free()
		_death_overlay = null
	emit_signal("respawn_requested")

func show_victory_screen(engine_name: String) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 320
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.10, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "THE RESONANCE"
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.6, 0.9, 1.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "%s assembled — the Periodic Wars are ended." % engine_name
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(0.9, 0.9, 0.8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(520, 0)
	vbox.add_child(sub)

	var body := Label.new()
	body.text = "The wells run clear. Ashvale breathes.\n\nYou learned the elements. You mastered the reactions.\nYou won the Periodic Wars."
	body.add_theme_font_size_override("font_size", 11)
	body.modulate = Color(0.75, 0.8, 0.75)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	vbox.add_child(body)

	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.94, 1.5)

func show_banner(text: String, color: Color = Color(0.7, 0.9, 1.0)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 70.0
	label.custom_minimum_size = Vector2(560, 0)
	label.z_index = 210
	add_child(label)

	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)
