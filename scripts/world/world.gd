extends Node2D

# Top-down procedural world — ColorRect tiles, no TileSet asset needed.
# Phase 2: swap ColorRects for TileMap + sprite sheet without changing any
# game logic — just replace _create_tile() internals.
#
# Performance model: tile_data stores the logical world for all 200×200 tiles
# (pure Dictionaries, no nodes). Visual ColorRect nodes and collision bodies
# are only created for tiles within VIEW_RADIUS of the player and destroyed
# when they scroll out of range.
#
# NOTE: at VIEW_RADIUS = 50 this is a (2*50+1)^2 = 10,201 tile window, so roughly
# 10k live ColorRects rather than the ~1,500 previously claimed here. It boots and
# runs, but lowering VIEW_RADIUS (~35 -> ~5k nodes) is a cheap win. The real fix is
# migrating to TileMap, which is worth doing once — and only once a real tileset
# exists, since the atlas layout drives the migration.

const TILE_SIZE: int = 16
const WORLD_WIDTH: int  = 200
const WORLD_HEIGHT: int = 200

# World pixel bounds — used by camera clamping
const WORLD_PX_W: float = WORLD_WIDTH  * TILE_SIZE
const WORLD_PX_H: float = WORLD_HEIGHT * TILE_SIZE

# How many tiles around the player get visual + collision nodes created.
# 1280×720 viewport at 16px tiles = 80×45 visible tiles — stream a bit beyond that.
const VIEW_RADIUS: int = 50

var _player_ref: Node2D = null     # set after player spawns
var _last_stream_tile: Vector2i = Vector2i(-9999, -9999)

# Tile colours (replace with atlas UVs when upgrading to TileMap)
const COLOR_GRASS  := Color(0.24, 0.65, 0.24)
const COLOR_DIRT   := Color(0.55, 0.37, 0.21)
const COLOR_STONE  := Color(0.45, 0.45, 0.45)
const COLOR_WATER  := Color(0.20, 0.55, 0.90)
const COLOR_SAND   := Color(0.87, 0.80, 0.55)
const COLOR_LAVA   := Color(0.95, 0.35, 0.05)
const COLOR_ROCK   := Color(0.35, 0.33, 0.30)

# Ore colours keyed by element symbol
const ORE_COLORS := {
	"Na": Color(0.9,  0.9,  0.3),
	"K":  Color(0.8,  0.6,  0.9),
	"C":  Color(0.15, 0.15, 0.15),
	"Fe": Color(0.7,  0.35, 0.1),
	"Cu": Color(0.72, 0.45, 0.2),
	"Zn": Color(0.6,  0.75, 0.75),
	"Ni": Color(0.5,  0.7,  0.5),
	"Ag": Color(0.85, 0.85, 0.90),
	"Au": Color(1.0,  0.85, 0.0),
	"Pt": Color(0.9,  0.95, 1.0),
	"U":  Color(0.2,  0.8,  0.2),
	"Th": Color(0.3,  0.9,  0.4),
}

# Biomes — horizontal regions across the X axis
const BIOMES := [
	{ "name": "surface_plains",    "x_start": 0,   "x_end": 39,  "base": "grass", "elements": ["Na","K","C"] },
	{ "name": "underground_mines", "x_start": 40,  "x_end": 79,  "base": "stone", "elements": ["Fe","Cu","Zn","Ni"] },
	{ "name": "crystal_caverns",   "x_start": 80,  "x_end": 109, "base": "stone", "elements": ["Ag","Au"] },
	{ "name": "sky_islands",       "x_start": 110, "x_end": 139, "base": "dirt",  "elements": ["K","Na"] },
	{ "name": "ocean_floor",       "x_start": 140, "x_end": 169, "base": "sand",  "elements": ["Cu","Zn"] },
	{ "name": "magma_layer",       "x_start": 170, "x_end": 199, "base": "stone", "elements": ["U","Th","Pt"] },
]

# tile_data[Vector2i] = { "type", "element", "passable", optionally "body" }
var tile_data: Dictionary = {}
var tile_nodes: Dictionary = {}        # Vector2i -> ColorRect
var _dug_tiles: Array[Vector2i] = []   # ore tiles removed this session

const ENEMY_SCENE:      String = "res://scenes/world/enemy.tscn"
const BOSS_SCENE:       String = "res://scenes/world/boss.tscn"
const SYNTH_SCENE:      String = "res://scenes/world/synthesizer.tscn"
const SYNTH_UI_SCENE:   String = "res://scenes/ui/synthesizer_ui.tscn"
const LAB_DESK_SCENE:   String = "res://scenes/world/lab_desk.tscn"
const MINIGAME_UI_SCENE: String = "res://scenes/ui/science_minigame_ui.tscn"
const STATION_SCENE:    String = "res://scenes/world/field_station.tscn"

# One boss per biome — placed near the far end of each biome zone
const BIOME_BOSSES: Dictionary = {
	"surface_plains":    "peroxis",
	"underground_mines": "chalcor",
	"crystal_caverns":   "aurium",
	"sky_islands":       "azrael",
	"ocean_floor":       "atacama",
	"magma_layer":       "uranox",
}

# How many enemies to spawn per biome at world start
const ENEMIES_PER_BIOME: int = 6
const RESPAWN_DELAY: float = 20.0       # seconds before a defeated enemy is replaced
const RESPAWN_MIN_DIST: float = 12.0 * 16.0   # replacements appear off-screen

# Creature IDs per biome (order: basic preferred → expert preferred)
const BIOME_CREATURES: Dictionary = {
	"surface_plains":    ["ashburn_shambler", "carbon_crawler", "potash_poltergeist"],
	"underground_mines": ["iron_hulk", "copper_coil", "zinc_phantom"],
	"crystal_caverns":   ["silver_specter", "gold_golem", "prismatic_hound"],
	"sky_islands":       ["alkali_hawk", "static_djinn", "stormwing"],
	"ocean_floor":       ["brine_crawler", "verdigris_lurker", "deep_shocker"],
	"magma_layer":       ["uranium_wraith", "thorium_scorcher", "platinum_sentinel"],
}

# Tier weights per biome — surface is mostly basic, magma is mostly expert
# [basic_weight, intermediate_weight, expert_weight]
const BIOME_TIER_WEIGHTS: Dictionary = {
	"surface_plains":    [0.70, 0.25, 0.05],
	"underground_mines": [0.50, 0.35, 0.15],
	"crystal_caverns":   [0.35, 0.45, 0.20],
	"sky_islands":       [0.40, 0.40, 0.20],
	"ocean_floor":       [0.30, 0.45, 0.25],
	"magma_layer":       [0.10, 0.35, 0.55],
}

# Ground tiles draw beneath everything that stands on them. Without this, tiles
# streamed in after the player were drawn on top of the player, Aldric and the
# scene-placed enemies, hiding them completely.
const GROUND_Z: int = -5

# Persisted so a loaded save gets the same map (SYSTEMS_UX_REVIEW §3.1).
var world_seed: int = -1
var defeated_bosses: Array = []   # boss_id strings; these never respawn
var boss_tiles: Dictionary = {}   # boss_id -> Vector2i, fixed by the seed
var stations: Dictionary = {}     # station_id -> FieldStation node
var discovered_stations: Array = []   # station_id strings (saved)

func _ready() -> void:
	# Characters, enemies and props sort by Y, so a 16×24 character walking
	# behind another overlaps it correctly.
	y_sort_enabled = true
	world_seed = SaveSystem.pending_world_seed()
	if world_seed < 0:
		world_seed = randi() & 0x7fffffff
	defeated_bosses = SaveSystem.pending_defeated_bosses().duplicate()
	SaveSystem.in_game = true
	tree_exiting.connect(func() -> void: SaveSystem.in_game = false)
	seed(world_seed)          # world generation is fully determined by the seed
	_generate_world()
	randomize()               # everything after generation stays random
	_spawn_village()
	_plan_boss_tiles()
	_spawn_stations()
	# Wire HUD and CraftingUI after the full scene tree is loaded
	call_deferred("_init_ui")
	call_deferred("_spawn_enemies")
	call_deferred("_spawn_bosses")

func _init_ui() -> void:
	var player := get_node_or_null("Player")
	var hud    := get_node_or_null("HUD")
	if hud and player:
		hud.init(player, self)
		_wire_player_lifecycle(player, hud)
		_wire_resonance(player, hud)
		_wire_encounters(hud)
		# Wire streaming — player position now known, do initial tile stream
		set_player_ref(player as Node2D)
		# Give CraftingUI a reference to the player inventory
		var crafting := get_node_or_null("CraftingUI")
		if crafting:
			var panel := crafting.get_node_or_null("Panel")
			if panel:
				panel.player_inventory = player.get_node_or_null("Inventory")
			crafting.add_to_group("crafting_ui")
		# Give player starter equipment so surface biome is immediately playable
		var equip := player.get_node_or_null("Equipment")
		if equip:
			equip.add_item("Standard Vial", 20)
			equip.add_item("Nitrile Gloves", 1)
		# Equip starter Bronze Sword (Tier 1) — craftable later via Cu+Sn
		if player.has_method("equip_weapon"):
			player.equip_weapon("bronze_sword")
		# Wire SynthesizerUI
		_spawn_synthesizer_ui(player)
		# Phase 6 — Science mini-game desk in Aldric's workshop
		_spawn_lab_desk()
		_spawn_minigame_ui()
		_spawn_inventory_screen()
		_spawn_journal_menus()
		_spawn_specimen_cabinet()
		_spawn_station_ui()
		# A loaded save overwrites the starter kit and moves the player.
		if SaveSystem.has_pending():
			SaveSystem.apply_pending(player)
			set_player_ref(player as Node2D)
		hud.connect_save_feedback()
		_spawn_autosave(player)

	# Set Aldric's dialogue via exported property override in code
	# (avoids needing to open the editor to set the Inspector fields)
	var aldric := get_node_or_null("Aldric")
	if aldric:
		aldric.npc_name = "Prof. Aldric Daedalus"
		aldric.portrait_color = Color(0.25, 0.45, 0.65)
		aldric.interact_radius = 40.0
		aldric.handles_resonance_assembly = true
		aldric.use_sprite_sheet("aldric")
		aldric.dialogue = ([
			"Orion! Just the person I needed. Come closer — these old ears aren't what they used to be.",
			"You've seen it too, haven't you? The water. Three wells have gone black this week alone.",
			"I've been running analyses. The contamination has an elemental signature — something is disrupting the hydrogen-oxygen bonds at a molecular level.",
			"It's not natural erosion. Something — or someone — is introducing a foreign compound into the aquifer.",
			"I have a theory, but I need your help to test it. Bring me two Hydrogen samples and one Oxygen sample. We'll synthesize a pure control batch and compare.",
			"You'll find the elements scattered around the plains. Use your hands — they're closer to the ground than mine these days.",
			"And Orion... before you go — there's a stack of research notes on my desk. Worth reading. Knowledge is as important as any weapon out there.",
			"Press [F] near the desk to study. Get enough right and you'll earn some element samples from my reserves. Don't worry, I have plenty.",
			"And Orion... be careful. The plains haven't felt right lately. I've noticed things moving at the edge of the fog.",
			"Go on then. The village is counting on us — even if they don't know it yet.",
		] as Array[String])

# ── Player lifecycle (death / respawn) ───────────────────────────────────────

# Ashvale village — matches the Player node's authored start position.
const PLAYER_SPAWN: Vector2 = Vector2(192, 192)

func _wire_player_lifecycle(player: Node, hud: Node) -> void:
	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died.bind(hud))
	if hud.has_signal("respawn_requested") and not hud.respawn_requested.is_connected(_on_respawn_requested):
		hud.respawn_requested.connect(_on_respawn_requested)
	if player.has_signal("ashmarks_dropped") and not player.ashmarks_dropped.is_connected(_on_ashmarks_dropped):
		player.ashmarks_dropped.connect(_on_ashmarks_dropped.bind(hud))

# Keep Inventory off: the cache is placed by the player; just tell them.
func _on_ashmarks_dropped(amount: int, _where: Vector2, hud: Node) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast("◈ Dropped %d Ashmarks where you fell" % amount, Color(0.84, 0.63, 0.25))

func _on_player_died(hud: Node) -> void:
	if hud and hud.has_method("show_death_screen"):
		hud.show_death_screen()

func _on_respawn_requested() -> void:
	var player := get_node_or_null("Player")
	if player and player.has_method("respawn"):
		player.respawn(PLAYER_SPAWN)
		set_player_ref(player as Node2D)

# ── Act 3 — Resonance Engine ─────────────────────────────────────────────────

# Banners for rare enemies and Prime Codex progress.
func _wire_encounters(hud: Node) -> void:
	if not EncounterSystem.rare_spawned.is_connected(_on_rare_spawned):
		EncounterSystem.rare_spawned.connect(_on_rare_spawned.bind(hud))
	if not EncounterSystem.prime_recorded.is_connected(_on_prime_recorded):
		EncounterSystem.prime_recorded.connect(_on_prime_recorded.bind(hud))
	if not EncounterSystem.prime_codex_completed.is_connected(_on_prime_codex_completed):
		EncounterSystem.prime_codex_completed.connect(_on_prime_codex_completed.bind(hud))

func _on_rare_spawned(creature_id: String, rarity: String, hud: Node) -> void:
	var creature_name: String = ElementDB.get_enemy_data(creature_id).get("name", creature_id)
	match rarity:
		"shiny":
			hud.show_banner("A shiny %s has appeared nearby..." % creature_name, Color(1.0, 0.85, 0.35))
		"prime":
			hud.show_banner("Something ancient stirs: a PRIME %s!" % creature_name, Color(0.9, 0.6, 1.0))

func _on_prime_recorded(creature_id: String, collected: int, total: int, hud: Node) -> void:
	var creature_name: String = ElementDB.get_enemy_data(creature_id).get("name", creature_id)
	hud.show_banner("Prime Codex: %s recorded (%d/%d)" % [creature_name, collected, total], Color(0.9, 0.6, 1.0))

func _on_prime_codex_completed(hud: Node) -> void:
	hud.show_banner("PRIME CODEX COMPLETE: every CHIMERA Prime recorded!", Color(1.0, 0.9, 0.5))

func _wire_resonance(_player: Node, hud: Node) -> void:
	if not ResonanceSystem.part_acquired.is_connected(_on_resonance_part):
		ResonanceSystem.part_acquired.connect(_on_resonance_part.bind(hud))
	if not ResonanceSystem.engine_ready.is_connected(_on_resonance_ready):
		ResonanceSystem.engine_ready.connect(_on_resonance_ready.bind(hud))
	if not ResonanceSystem.engine_assembled.is_connected(_on_engine_assembled):
		ResonanceSystem.engine_assembled.connect(_on_engine_assembled.bind(hud))

func _on_resonance_part(item_key: String, collected: int, total: int, hud: Node) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Resonance component built: %s  (%d/%d)"
			% [ResonanceSystem.display_name_for(item_key), collected, total],
			Color(0.6, 0.9, 1.0))

func _on_resonance_ready(hud: Node) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner("All six components complete — bring them to Prof. Aldric Daedalus in Ashvale.",
			Color(1.0, 0.9, 0.4))

func _on_engine_assembled(engine_name: String, hud: Node) -> void:
	if hud and hud.has_method("show_victory_screen"):
		hud.show_victory_screen(engine_name)

# ── Generation ────────────────────────────────────────────────────────────────

func _generate_world() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.05

	# Pure data pass — no nodes created here.
	for x: int in range(WORLD_WIDTH):
		var biome := _get_biome(x)
		for y: int in range(WORLD_HEIGHT):
			var coords := Vector2i(x, y)
			var n: float = noise.get_noise_2d(x, y)

			if biome.name == "ocean_floor" and n > 0.3:
				tile_data[coords] = { "type": "water",  "element": "", "passable": false, "color": COLOR_WATER }
				continue
			if biome.name == "magma_layer" and n > 0.4:
				tile_data[coords] = { "type": "lava",   "element": "", "passable": false, "color": COLOR_LAVA }
				continue
			if n > 0.55:
				tile_data[coords] = { "type": "rock",   "element": "", "passable": false, "color": COLOR_ROCK }
				continue

			var ore_n: float = noise.get_noise_2d(x * 4.1, y * 4.1)
			if ore_n > 0.5 and biome.elements.size() > 0:
				var idx: int = int(abs(ore_n * 10)) % (biome.elements.size() as int)
				var element: String = biome.elements[idx]
				tile_data[coords] = { "type": "ore", "element": element, "passable": true, "color": ORE_COLORS.get(element, Color.WHITE) }
				continue

			tile_data[coords] = { "type": biome.base, "element": "", "passable": true, "color": _base_color(biome.base) }

# Called once after the player node is ready so streaming can start.
func set_player_ref(player: Node2D) -> void:
	_player_ref = player
	_stream_tiles_around(world_to_tile(player.global_position))

func _process(_delta: float) -> void:
	if _player_ref == null:
		return
	var pt := world_to_tile(_player_ref.global_position)
	# Only re-stream when the player moves to a new tile
	if pt == _last_stream_tile:
		return
	_last_stream_tile = pt
	_stream_tiles_around(pt)

func _stream_tiles_around(center: Vector2i) -> void:
	var x_min: int = maxi(center.x - VIEW_RADIUS, 0)
	var x_max: int = mini(center.x + VIEW_RADIUS, WORLD_WIDTH  - 1)
	var y_min: int = maxi(center.y - VIEW_RADIUS, 0)
	var y_max: int = mini(center.y + VIEW_RADIUS, WORLD_HEIGHT - 1)

	# Build set of tiles that should be active
	var wanted: Dictionary = {}
	for x: int in range(x_min, x_max + 1):
		for y: int in range(y_min, y_max + 1):
			wanted[Vector2i(x, y)] = true

	# Destroy nodes no longer in view
	var to_remove: Array[Vector2i] = []
	for coords: Vector2i in tile_nodes:
		if not wanted.has(coords):
			to_remove.append(coords)
	for coords: Vector2i in to_remove:
		tile_nodes[coords].queue_free()
		tile_nodes.erase(coords)
		var td: Dictionary = tile_data.get(coords, {})
		if td.has("body"):
			td["body"].queue_free()
			td.erase("body")

	# Create nodes for newly-visible tiles
	for coords: Vector2i in wanted:
		if tile_nodes.has(coords):
			continue
		var td: Dictionary = tile_data.get(coords, {})
		if td.is_empty():
			continue
		_materialise_tile(coords, td)

func _materialise_tile(coords: Vector2i, td: Dictionary) -> void:
	var col: Color = td.get("color", Color.MAGENTA)
	var rect := ColorRect.new()
	rect.color = col
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(coords.x * TILE_SIZE, coords.y * TILE_SIZE)
	rect.z_index = GROUND_Z
	add_child(rect)
	tile_nodes[coords] = rect

	if not bool(td.get("passable", true)):
		var body := StaticBody2D.new()
		body.position = rect.position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = box
		body.collision_layer = 1
		body.add_child(shape)
		add_child(body)
		tile_data[coords]["body"] = body

func _spawn_village() -> void:
	# Ashvale village in the surface_plains biome, centred around tile (15,15)
	# Buildings are impassable rock-coloured rectangles.
	# SPRITE SWAP: replace ColorRect logic here with instanced building scenes.
	var buildings := [
		{ "x": 10, "y": 10, "w": 5, "h": 4, "label": "Aldric's Workshop",  "color": Color(0.45, 0.30, 0.15) },
		{ "x": 17, "y": 10, "w": 4, "h": 3, "label": "Village Hall",       "color": Color(0.60, 0.50, 0.35) },
		{ "x": 10, "y": 16, "w": 3, "h": 3, "label": "House",              "color": Color(0.55, 0.45, 0.30) },
		{ "x": 15, "y": 16, "w": 3, "h": 3, "label": "House",              "color": Color(0.55, 0.45, 0.30) },
		{ "x": 20, "y": 15, "w": 3, "h": 3, "label": "Market Stall",       "color": Color(0.70, 0.60, 0.20) },
		{ "x": 13, "y": 13, "w": 2, "h": 2, "label": "Well",               "color": Color(0.35, 0.55, 0.75) },
	]
	for b: Dictionary in buildings:
		for bx: int in range(int(b.w)):
			for by: int in range(int(b.h)):
				var coords := Vector2i(int(b.x) + bx, int(b.y) + by)
				# Data-only — node created by streaming when player is nearby
				tile_data[coords] = { "type": "building", "element": "", "passable": false, "color": b.color as Color }

# ── Tile helpers ──────────────────────────────────────────────────────────────

func _get_biome(x: int) -> Dictionary:
	for b: Dictionary in BIOMES:
		if x >= int(b.x_start) and x <= int(b.x_end):
			return b
	return BIOMES[0]

func _base_color(base: String) -> Color:
	match base:
		"grass": return COLOR_GRASS
		"stone": return COLOR_STONE
		"sand":  return COLOR_SAND
		_:       return COLOR_DIRT

func _create_tile(coords: Vector2i, color: Color, type: String, element: String, passable: bool) -> void:
	# Remove any existing nodes first
	if tile_nodes.has(coords):
		tile_nodes[coords].queue_free()
		tile_nodes.erase(coords)
	if tile_data.has(coords) and tile_data[coords].has("body"):
		tile_data[coords]["body"].queue_free()

	# Write data record
	tile_data[coords] = { "type": type, "element": element, "passable": passable, "color": color }

	# Materialise immediately only if this tile is within the current stream window
	if _is_in_view(coords):
		_materialise_tile(coords, tile_data[coords])

func _is_in_view(coords: Vector2i) -> bool:
	if _last_stream_tile == Vector2i(-9999, -9999):
		return true  # before first stream — materialise everything (village/synthesizer spawns)
	return (abs(coords.x - _last_stream_tile.x) <= VIEW_RADIUS and
	        abs(coords.y - _last_stream_tile.y) <= VIEW_RADIUS)

# ── Public API ────────────────────────────────────────────────────────────────

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

func get_biome_at(world_pos: Vector2) -> String:
	var tile := world_to_tile(world_pos)
	return _get_biome(tile.x).get("name", "unknown")

func dig_tile(tile_coords: Vector2i) -> String:
	var data: Dictionary = tile_data.get(tile_coords, {})
	if data.is_empty() or not data.get("passable", true):
		return ""
	var element: String = data.get("element", "")
	if element == "":
		return ""
	# Remove ore tile, replace with passable ground
	var biome := _get_biome(tile_coords.x)
	_create_tile(tile_coords, _base_color(biome.base), biome.base, "", true)
	_dug_tiles.append(tile_coords)
	return element

func serialize_dug_tiles() -> Array:
	var result: Array = []
	for coords: Vector2i in _dug_tiles:
		result.append([coords.x, coords.y])
	return result

func restore_dug_tiles(dug: Array) -> void:
	for entry: Variant in dug:
		var arr: Array = entry as Array
		if arr.size() < 2:
			continue
		var coords := Vector2i(int(arr[0]), int(arr[1]))
		var td: Dictionary = tile_data.get(coords, {})
		if td.get("type", "") == "ore":
			var biome := _get_biome(coords.x)
			_create_tile(coords, _base_color(biome.base), biome.base, "", true)
		_dug_tiles.append(coords)

func _spawn_enemies() -> void:
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	if enemy_scene == null:
		return
	for biome: Dictionary in BIOMES:
		for i: int in range(ENEMIES_PER_BIOME):
			_spawn_enemy_in_biome(enemy_scene, biome, i, Vector2.INF)

# Places one enemy at a random passable tile in the biome, outside the village
# and (for respawns) at least RESPAWN_MIN_DIST from the player. Every spawn is
# one encounter: EncounterSystem rolls its rarity (strong / shiny / prime).
func _spawn_enemy_in_biome(enemy_scene: PackedScene, biome: Dictionary, index: int, avoid: Vector2) -> Node:
	# Village safe zone
	const SAFE_X_MIN: int = 8
	const SAFE_X_MAX: int = 24
	const SAFE_Y_MIN: int = 8
	const SAFE_Y_MAX: int = 24
	var biome_name: String = biome.get("name", "")
	var creature_ids: Array = BIOME_CREATURES.get(biome_name, [])
	if creature_ids.is_empty():
		return null
	var tier_weights: Array = BIOME_TIER_WEIGHTS.get(biome_name, [0.6, 0.3, 0.1])
	for _attempt: int in range(30):
		var tx: int = randi_range(int(biome.x_start), int(biome.x_end))
		var ty: int = randi_range(0, WORLD_HEIGHT - 1)
		if tx >= SAFE_X_MIN and tx <= SAFE_X_MAX and ty >= SAFE_Y_MIN and ty <= SAFE_Y_MAX:
			continue
		var td: Dictionary = tile_data.get(Vector2i(tx, ty), {})
		if not td.get("passable", false):
			continue
		var pos := Vector2(tx * TILE_SIZE + TILE_SIZE / 2.0, ty * TILE_SIZE + TILE_SIZE / 2.0)
		if avoid != Vector2.INF and pos.distance_to(avoid) < RESPAWN_MIN_DIST:
			continue
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		enemy.position = pos
		# Cycle through the biome's creatures for variety
		enemy.creature_id = creature_ids[index % creature_ids.size()]
		enemy.tier = _pick_tier(tier_weights)
		enemy.rarity = EncounterSystem.roll_rarity(enemy.creature_id)
		add_child(enemy)
		_watch_for_bestiary(enemy)
		return enemy
	return null

# Called by enemy.gd on death: a replacement appears in the same biome after a
# delay, so the population (and the rare-spawn rolls) never run out.
func on_enemy_defeated(enemy: Node) -> void:
	var biome_name: String = get_biome_at((enemy as Node2D).global_position)
	var creature_id: String = enemy.creature_id
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(func() -> void:
		_respawn_enemy(biome_name, creature_id))

func _respawn_enemy(biome_name: String, creature_id: String) -> void:
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	for biome: Dictionary in BIOMES:
		if biome.get("name", "") != biome_name:
			continue
		var ids: Array = BIOME_CREATURES.get(biome_name, [])
		var player := get_node_or_null("Player") as Node2D
		var avoid: Vector2 = player.global_position if player else Vector2.INF
		_spawn_enemy_in_biome(enemy_scene, biome, maxi(ids.find(creature_id), 0), avoid)
		return

func _pick_tier(weights: Array) -> String:
	var r: float = randf()
	if r < float(weights[0]):
		return "basic"
	elif r < float(weights[0]) + float(weights[1]):
		return "intermediate"
	return "expert"

func _spawn_bosses() -> void:
	var boss_scene: PackedScene = load(BOSS_SCENE)
	if boss_scene == null:
		return

	for biome: Dictionary in BIOMES:
		var biome_name: String = biome.get("name", "")
		var boss_id: String = BIOME_BOSSES.get(biome_name, "")
		if boss_id == "" or boss_id in defeated_bosses:
			continue

		# Lair chosen by _plan_boss_tiles() (seeded, so its Field Station matches)
		if not boss_tiles.has(boss_id):
			continue
		var boss: CharacterBody2D = boss_scene.instantiate()
		boss.boss_id  = boss_id
		boss.position = _tile_centre(boss_tiles[boss_id])

		# Create and wire the arena node
		var arena := Node2D.new()
		arena.set_script(load("res://scripts/world/boss_arena.gd"))
		arena.name = "Arena_%s" % boss_id
		add_child(arena)
		boss._arena = arena

		add_child(boss)
		# Arena scales with the boss (size is known once its data loads):
		# room to dash around a huge body.
		if arena.has_method("init"):
			arena.init(boss.position, maxf(160.0, boss.body_size * 2.5))

# Called by boss.gd when a boss dies; saved so it stays beaten.
func on_boss_defeated(boss_id: String) -> void:
	if not boss_id in defeated_bosses:
		defeated_bosses.append(boss_id)
	_request_autosave("boss")

func _spawn_synthesizer_ui(player: Node) -> void:
	# Spawn Synthesizer world object near village (tile 22,12 — east of workshop)
	var synth_scene: PackedScene = load(SYNTH_SCENE)
	if synth_scene:
		var synth: Node2D = synth_scene.instantiate()
		synth.position = Vector2(22 * TILE_SIZE + TILE_SIZE / 2.0, 12 * TILE_SIZE + TILE_SIZE / 2.0)
		add_child(synth)
		_create_tile(Vector2i(22, 12), Color(0.15, 0.65, 0.85), "building", "", false)

	# Spawn SynthesizerUI as CanvasLayer child of world
	var synth_ui_scene: PackedScene = load(SYNTH_UI_SCENE)
	if synth_ui_scene == null:
		return
	var synth_ui: Node = synth_ui_scene.instantiate()
	add_child(synth_ui)
	# Wire player inventory and equipment
	synth_ui.player_inventory = player.get_node_or_null("Inventory")
	synth_ui.player_equipment = player.get_node_or_null("Equipment")

func _spawn_lab_desk() -> void:
	# Place Aldric's research desk inside his workshop (tile 12, 11)
	# Workshop occupies tiles (10,10)→(14,13); desk sits one tile inside.
	var desk_scene: PackedScene = load(LAB_DESK_SCENE)
	if desk_scene == null:
		return
	var desk: Node2D = desk_scene.instantiate()
	desk.position = Vector2(12 * TILE_SIZE + TILE_SIZE / 2.0, 11 * TILE_SIZE + TILE_SIZE / 2.0)
	add_child(desk)

func _spawn_inventory_screen() -> void:
	var screen := CanvasLayer.new()
	screen.set_script(load("res://scripts/ui/inventory_screen.gd"))
	screen.name = "InventoryScreen"
	add_child(screen)

# Contents hub (Esc) and Bestiary pages of the journal.
func _spawn_journal_menus() -> void:
	for entry: Array in [["ContentsHub", "res://scripts/ui/contents_hub.gd"], ["Bestiary", "res://scripts/ui/bestiary_ui.gd"]]:
		var menu := CanvasLayer.new()
		menu.set_script(load(entry[1]))
		menu.name = entry[0]
		add_child(menu)
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		_watch_for_bestiary(enemy)

# Specimen Cabinet against the east wall inside Aldric's workshop (tiles 10–14 × 10–13).
func _spawn_specimen_cabinet() -> void:
	var cabinet := Node2D.new()
	cabinet.set_script(load("res://scripts/world/specimen_cabinet.gd"))
	cabinet.name = "SpecimenCabinet"
	cabinet.position = Vector2(14 * TILE_SIZE + TILE_SIZE / 2.0, 12 * TILE_SIZE + TILE_SIZE / 2.0)
	add_child(cabinet)

# A creature counts as seen for the Bestiary once it comes on screen.
func _watch_for_bestiary(enemy: Node) -> void:
	if not ("creature_id" in enemy) or not (enemy is Node2D):
		return
	var eye := VisibleOnScreenNotifier2D.new()
	eye.rect = Rect2(-16, -16, 32, 32)
	eye.screen_entered.connect(func() -> void: EncounterSystem.mark_seen(enemy.creature_id), CONNECT_ONE_SHOT)
	enemy.add_child(eye)

func _spawn_minigame_ui() -> void:
	var ui_scene: PackedScene = load(MINIGAME_UI_SCENE)
	if ui_scene == null:
		return
	var ui: Node = ui_scene.instantiate()
	add_child(ui)

# ── Field Stations, fast travel, autosave (SYSTEMS_UX_REVIEW §3.1) ────────────

const STATION_GAP: float = 40.0   # px between a boss arena's edge and its station
const VILLAGE_STATION_TILE := Vector2i(18, 21)   # south of the Ashvale houses

func _tile_centre(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE_SIZE + TILE_SIZE / 2.0, t.y * TILE_SIZE + TILE_SIZE / 2.0)

# Each boss's lair, picked from the world seed so the boss (and the station
# outside its arena) is in the same place after every load.
func _plan_boss_tiles() -> void:
	boss_tiles.clear()
	for biome: Dictionary in BIOMES:
		var boss_id: String = BIOME_BOSSES.get(biome.get("name", ""), "")
		if boss_id == "":
			continue
		var bx_start: int = int(biome.x_start)
		var bx_end: int = int(biome.x_end)
		# Far two-thirds of the biome, away from the entrance
		@warning_ignore("integer_division")
		var x_min: int = bx_start + (bx_end - bx_start) * 2 / 3
		var x_max: int = bx_end - 2
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [world_seed, boss_id])
		for _attempt: int in range(50):
			var t := Vector2i(rng.randi_range(x_min, x_max), rng.randi_range(10, WORLD_HEIGHT - 10))
			if tile_data.get(t, {}).get("passable", false):
				boss_tiles[boss_id] = t
				break

# Arena radius in px for a boss, as _spawn_bosses() will size it.
func boss_arena_radius(boss_id: String) -> float:
	var f := FileAccess.open("res://data/boss_data.json", FileAccess.READ)
	if f == null:
		return 160.0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for b: Dictionary in (parsed as Dictionary).get("bosses", []):
			if b.get("id", "") == boss_id:
				return maxf(160.0, float(b.get("size", 128)) * 2.5)
	return 160.0

func _spawn_stations() -> void:
	var scene: PackedScene = load(STATION_SCENE)
	if scene == null:
		return
	_clear_plot(VILLAGE_STATION_TILE)
	_add_station(scene, "ashvale", "Ashvale Field Station", VILLAGE_STATION_TILE)
	for biome: Dictionary in BIOMES:
		var biome_name: String = biome.get("name", "")
		# Surface Plains' entrance station is the one in Ashvale.
		if int(biome.x_start) > 0:
			var t := _find_station_tile(Vector2i(int(biome.x_start) + 4, 20), biome, 0.0)
			_add_station(scene, "entrance_" + biome_name, "%s Camp" % biome_name.capitalize(), t)
		var boss_id: String = BIOME_BOSSES.get(biome_name, "")
		if boss_tiles.has(boss_id):
			var dist: float = boss_arena_radius(boss_id) + STATION_GAP
			var t := _find_station_tile(boss_tiles[boss_id], biome, dist)
			_add_station(scene, "boss_" + boss_id, "%s Lair Camp" % boss_id.capitalize(), t)

func _add_station(scene: PackedScene, id: String, title: String, t: Vector2i) -> void:
	var st: Node2D = scene.instantiate()
	st.name = "Station_%s" % id
	st.station_id = id
	st.display_name = title
	st.position = _tile_centre(t)
	add_child(st)
	stations[id] = st
	if id in discovered_stations:
		st.set_discovered(true)

# A spot whose 5×5 plot is open ground. dist == 0: nearest to `origin`;
# dist > 0: on a ring that far (px) from `origin`, preferring the side facing
# the biome's entrance (west), and staying inside the biome.
func _find_station_tile(origin: Vector2i, biome: Dictionary, dist: float) -> Vector2i:
	var x_lo: int = maxi(int(biome.x_start) + 2, 2)
	var x_hi: int = mini(int(biome.x_end) - 2, WORLD_WIDTH - 3)
	var candidates: Array[Vector2i] = []
	if dist <= 0.0:
		for r: int in range(0, 40):
			for dx: int in range(-r, r + 1):
				for dy: int in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) == r:
						candidates.append(origin + Vector2i(dx, dy))
	else:
		var r_tiles: float = dist / TILE_SIZE
		for deg: float in [180.0, 150.0, 210.0, 120.0, 240.0, 90.0, 270.0, 60.0, 300.0, 30.0, 330.0, 0.0]:
			var dir := Vector2.from_angle(deg_to_rad(deg))
			for extra: int in range(0, 6):
				var p: Vector2 = Vector2(origin) + dir * (r_tiles + extra)
				candidates.append(Vector2i(roundi(p.x), roundi(p.y)))
	var fallback := Vector2i(-1, -1)
	for c: Vector2i in candidates:
		if c.x < x_lo or c.x > x_hi or c.y < 3 or c.y > WORLD_HEIGHT - 4:
			continue
		# Lair camps stay out of Ashvale (it has its own station).
		if dist > 0.0 and c.x >= 6 and c.x <= 26 and c.y >= 6 and c.y <= 26:
			continue
		if fallback.x < 0:
			fallback = c
		if _plot_is_open(c):
			return c
	if fallback.x < 0:
		fallback = Vector2i(clampi(origin.x, x_lo, x_hi), clampi(origin.y, 3, WORLD_HEIGHT - 4))
	_clear_plot(fallback)
	return fallback

func _plot_is_open(c: Vector2i) -> bool:
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			var td: Dictionary = tile_data.get(c + Vector2i(dx, dy), {})
			if not td.get("passable", false) or td.get("type", "") == "ore":
				return false
	return true

# Data-only: turn the plot into plain biome ground (nodes stream in later).
func _clear_plot(c: Vector2i) -> void:
	var biome := _get_biome(c.x)
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			var t := c + Vector2i(dx, dy)
			if tile_data.has(t) and tile_data[t].get("type", "") != "building":
				tile_data[t] = { "type": biome.base, "element": "", "passable": true, "color": _base_color(biome.base) }

func on_station_discovered(station_id: String) -> void:
	if station_id in discovered_stations:
		return
	discovered_stations.append(station_id)
	var st: Node = stations.get(station_id)
	if st:
		st.set_discovered(true)
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_banner") and st:
		hud.show_banner("Field Station discovered: %s" % st.display_name, Color(0.95, 0.8, 0.45))
	_request_autosave("station")

func serialize_stations() -> Array:
	return discovered_stations.duplicate()

func restore_stations(ids: Array) -> void:
	discovered_stations.clear()
	for id: Variant in ids:
		if not str(id) in discovered_stations:
			discovered_stations.append(str(id))
	for id: String in stations:
		stations[id].set_discovered(id in discovered_stations)

# The discovered station the player is standing at, or null.
func station_near(pos: Vector2) -> Node:
	for id: String in discovered_stations:
		var st: Node2D = stations.get(id)
		if st and st.global_position.distance_to(pos) <= float(st.interact_radius) + 8.0:
			return st
	return null

func travel_to_station(station_id: String) -> bool:
	var st: Node2D = stations.get(station_id)
	var player := get_node_or_null("Player") as Node2D
	if st == null or player == null or not station_id in discovered_stations:
		return false
	player.global_position = st.arrival_position()
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	set_player_ref(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
	return true

# A boss is fighting the player (and the player hasn't fled far away).
func is_boss_fight_active() -> bool:
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		return false
	for b: Node in get_children():
		if not ("boss_id" in b and "_state" in b) or b._state != "combat":
			continue
		var arena_r: float = float(b._arena._arena_radius) if b._arena and "_arena_radius" in b._arena else 160.0
		if (b as Node2D).global_position.distance_to(player.global_position) <= arena_r + float(b.sight_range):
			return true
	return false

func _request_autosave(reason: String) -> void:
	var auto := get_node_or_null("Autosave")
	if auto:
		auto.request(reason)

func _spawn_autosave(player: Node) -> void:
	var auto := Node.new()
	auto.set_script(load("res://scripts/world/autosave_director.gd"))
	auto.name = "Autosave"
	add_child(auto)
	auto.setup(self, player)

func _spawn_station_ui() -> void:
	for script_path: String in ["res://scripts/ui/station_menu.gd", "res://scripts/ui/map_screen.gd"]:
		var ui := CanvasLayer.new()
		ui.set_script(load(script_path))
		ui.name = script_path.get_file().get_basename().to_pascal_case()
		add_child(ui)
