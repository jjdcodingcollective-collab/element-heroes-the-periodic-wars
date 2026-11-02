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
	_init_hotbar_and_hints(player)

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
	_tick_ore_hint(delta)

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
	UIManager.toggle("compendium")

func toggle_crafting() -> void:
	UIManager.toggle("crafting")

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

# "Journal saved" toast for every save (manual, autosave, suspend).
func connect_save_feedback() -> void:
	if not SaveSystem.saved.is_connected(_on_saved):
		SaveSystem.saved.connect(_on_saved)

func _on_saved(slot: String, ok: bool) -> void:
	if not ok:
		show_toast("Could not save!", Color(1.0, 0.45, 0.4))
	elif slot == "autosave":
		show_toast("✎ Autosaved")
	else:
		show_toast("✎ Journal saved")

# Small bottom-right note that fades out; does not interrupt play.
func show_toast(text: String, colour: Color = Color(0.96, 0.9, 0.75)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	# Offsets from the bottom-right anchor (setting `position` after anchoring
	# doubled the viewport size and put the toast off-screen).
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.offset_left = -230.0
	l.offset_top = -100.0
	l.offset_right = -12.0
	l.offset_bottom = -76.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(l)
	var tween := l.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(l, "modulate:a", 0.0, 0.6)
	tween.tween_callback(l.queue_free)

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

# ── Hotbar, ore container hint, low-vial warning (SYSTEMS_UX_REVIEW.md §3.3) ──

const JS := preload("res://scripts/ui/journal_style.gd")
const ITEM_ICON_DIR := "res://assets/sprites/items/"
const HOTBAR_SLOT := 44.0
const HOTBAR_GAP := 6.0
const ORE_HINT_INTERVAL: float = 0.15
const LOW_VIAL_THRESHOLD: int = 3

var _hotbar_root: Control = null
var _hotbar_slots: Array = []   # [{frame, icon, count}]
var _ore_hint: PanelContainer = null
var _ore_hint_label: Label = null
var _ore_hint_timer: float = 0.0
var _last_vials: int = -1

func _init_hotbar_and_hints(player: Node) -> void:
	_build_hotbar()
	_build_ore_hint()
	var bag := player.get_node_or_null("Bag")
	if bag:
		if bag.has_signal("hotbar_changed"):
			bag.hotbar_changed.connect(_refresh_hotbar)
		bag.bag_changed.connect(_refresh_hotbar)
		if bag.has_signal("boss_key_requested"):
			bag.boss_key_requested.connect(_on_boss_key_requested)
	var equip := player.get_node_or_null("Equipment")
	if equip:
		_last_vials = int(equip.get_all().get("Standard Vial", 0))
		equip.equipment_changed.connect(_check_low_vials)
	_refresh_hotbar()

func _build_hotbar() -> void:
	if _hotbar_root != null:
		return
	var width: float = HOTBAR_SLOT * 4.0 + HOTBAR_GAP * 3.0
	_hotbar_root = Control.new()
	_hotbar_root.name = "Hotbar"
	_hotbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_root.anchor_left = 0.5
	_hotbar_root.anchor_right = 0.5
	_hotbar_root.anchor_top = 1.0
	_hotbar_root.anchor_bottom = 1.0
	_hotbar_root.offset_left = -width / 2.0
	_hotbar_root.offset_right = width / 2.0
	_hotbar_root.offset_top = -40.0 - HOTBAR_SLOT
	_hotbar_root.offset_bottom = -40.0
	add_child(_hotbar_root)
	for i: int in 4:
		var frame := Panel.new()
		frame.position = Vector2(i * (HOTBAR_SLOT + HOTBAR_GAP), 0)
		frame.size = Vector2(HOTBAR_SLOT, HOTBAR_SLOT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar_root.add_child(frame)
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(6, 6)
		icon.size = Vector2(32, 32)   # 16×16 icon at ×2
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
		var key := JS.label(str(i + 1), 10, JS.INK)
		key.position = Vector2(3, -1)
		frame.add_child(key)
		var count := JS.label("", 11, JS.CREAM_TEXT)
		count.add_theme_color_override("font_outline_color", JS.LEATHER_DARK)
		count.add_theme_constant_override("outline_size", 4)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(0, HOTBAR_SLOT - 18)
		count.size = Vector2(HOTBAR_SLOT - 3, 16)
		frame.add_child(count)
		_hotbar_slots.append({ "frame": frame, "icon": icon, "count": count })

func _refresh_hotbar() -> void:
	if _hotbar_root == null or _player == null:
		return
	var bag := _player.get_node_or_null("Bag")
	for i: int in _hotbar_slots.size():
		var s: Dictionary = _hotbar_slots[i]
		var id: String = bag.hotbar_item(i) if bag else ""
		var n: int = bag.hotbar_count(i) if bag else 0
		var filled: bool = id != "" and n > 0
		(s["frame"] as Panel).add_theme_stylebox_override("panel",
			JS.box(JS.PAGE if filled else Color(JS.PAGE_DARK, 0.55), JS.BRASS if filled else JS.LEATHER, 2, 4))
		var path := ITEM_ICON_DIR + id + ".png"
		(s["icon"] as TextureRect).texture = load(path) as Texture2D if filled and ResourceLoader.exists(path) else null
		var count_text := ""
		if filled:
			count_text = "★" if bag.is_boss_key(id) and bag.consumable_count(id) <= 0 else "×%d" % n
		(s["count"] as Label).text = count_text

# Hotbar Boss Key: the hook lives in Bag.use_boss_key; boss use comes later.
func _on_boss_key_requested(_id: String) -> void:
	show_toast("Boss Key ready", JS.BRASS)

func _build_ore_hint() -> void:
	if _ore_hint != null:
		return
	_ore_hint = PanelContainer.new()
	_ore_hint.name = "OreHint"
	_ore_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := JS.box(Color(JS.PAGE, 0.94), JS.LEATHER, 2, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_ore_hint.add_theme_stylebox_override("panel", style)
	_ore_hint.anchor_left = 0.5
	_ore_hint.anchor_right = 0.5
	_ore_hint.anchor_top = 1.0
	_ore_hint.anchor_bottom = 1.0
	_ore_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ore_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ore_hint.offset_top = -48.0 - HOTBAR_SLOT - 24.0
	_ore_hint.offset_bottom = -48.0 - HOTBAR_SLOT
	_ore_hint_label = JS.label("", 13, JS.INK)
	_ore_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ore_hint.add_child(_ore_hint_label)
	_ore_hint.visible = false
	add_child(_ore_hint)

# "Fe → Standard Vial ✓" / "U → needs Radiation Suit + Lead Container ✗".
# Mirrors Equipment.can_collect and consume_container_for.
func container_hint(symbol: String) -> Dictionary:
	var equip: Node = _player.get_node_or_null("Equipment") if _player else null
	var h: Dictionary = ElementDB.get_handling(symbol)
	var need_container: String = str(h.get("container_item", "Standard Vial"))
	if need_container == "":
		need_container = "Standard Vial"
	var need_handling: String = str(h.get("handling_item", ""))
	var items: Dictionary = equip.get_all() if equip else {}
	var missing: Array = []
	if need_handling != "":
		var ok_h := false
		if equip:
			var req: int = int(equip.HANDLING_TIER.get(need_handling, 0))
			for item: String in items:
				if int(items[item]) > 0 and equip.HANDLING_TIER.has(item) and int(equip.HANDLING_TIER[item]) >= req:
					ok_h = true
		if not ok_h:
			missing.append(need_handling)
	var use := ""
	if equip:
		var req_c: int = int(equip.CONTAINER_TIER.get(need_container, 0))
		var best: int = 9999
		for item: String in items:
			if int(items[item]) > 0 and equip.CONTAINER_TIER.has(item) and item not in equip.REUSABLE:
				var t: int = int(equip.CONTAINER_TIER[item])
				if t >= req_c and t < best:
					best = t
					use = item
	if use == "":
		missing.append(need_container)
	if missing.is_empty():
		return { "text": "%s → %s ✓" % [symbol, use], "ok": true, "container": use }
	return { "text": "%s → needs %s ✗" % [symbol, " + ".join(missing)], "ok": false, "container": need_container }

# Nearest ore tile the player could dig: the one under the mouse if it is in
# range, otherwise the closest within Player.DIG_RANGE. "" if none.
func ore_in_dig_range() -> String:
	if _world == null or _player == null or not ("tile_data" in _world):
		return ""
	var range_px: float = float(_player.DIG_RANGE) if "DIG_RANGE" in _player else 48.0
	var ppos: Vector2 = (_player as Node2D).global_position
	var tiles: Dictionary = _world.tile_data
	var mouse: Vector2 = (_player as Node2D).get_global_mouse_position()
	if ppos.distance_to(mouse) <= range_px:
		var mtd: Dictionary = tiles.get(_world.world_to_tile(mouse), {})
		if mtd.get("type", "") == "ore" and str(mtd.get("element", "")) != "":
			return str(mtd["element"])
	var tile_px: float = 16.0
	var centre: Vector2i = _world.world_to_tile(ppos)
	var reach: int = int(ceil(range_px / tile_px))
	var best := ""
	var best_d: float = INF
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var c := centre + Vector2i(dx, dy)
			var td: Dictionary = tiles.get(c, {})
			if td.get("type", "") != "ore" or str(td.get("element", "")) == "":
				continue
			var d: float = ppos.distance_to((Vector2(c) + Vector2(0.5, 0.5)) * tile_px)
			if d <= range_px and d < best_d:
				best_d = d
				best = str(td["element"])
	return best

func _tick_ore_hint(delta: float) -> void:
	if _ore_hint == null:
		return
	_ore_hint_timer += delta
	if _ore_hint_timer < ORE_HINT_INTERVAL:
		return
	_ore_hint_timer = 0.0
	update_ore_hint()

func update_ore_hint() -> void:
	if _ore_hint == null or _player == null:
		return
	var symbol := "" if bool(_player.get("is_dead")) else ore_in_dig_range()
	_ore_hint.visible = symbol != ""
	if symbol == "":
		return
	var hint := container_hint(symbol)
	_ore_hint_label.text = hint["text"]
	_ore_hint_label.add_theme_color_override("font_color", JS.INK_GREEN if hint["ok"] else JS.STAMP_RED)

# Toast when Standard Vials run low (3 or fewer), each time one is used up.
func _check_low_vials() -> void:
	var equip := _player.get_node_or_null("Equipment") if _player else null
	if equip == null:
		return
	var n: int = int(equip.get_all().get("Standard Vial", 0))
	if _last_vials >= 0 and n < _last_vials and n <= LOW_VIAL_THRESHOLD:
		show_toast(low_vial_text(n), Color(1.0, 0.72, 0.35))
	_last_vials = n

static func low_vial_text(n: int) -> String:
	if n <= 0:
		return "No Standard Vials left!"
	return "Only %d Standard Vial%s left" % [n, "" if n == 1 else "s"]
