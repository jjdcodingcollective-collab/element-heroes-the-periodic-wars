extends RefCounted

# The Prime cosmetic set (BOSS_DESIGN.md §4a), earned in steps from Prime
# Codex progress. Shared by the Bestiary and the Specimen Cabinet.
#   const PrimeSet := preload("res://scripts/world/prime_set.gd")

const BIOME_ORDER := ["surface_plains", "underground_mines", "crystal_caverns", "sky_islands", "ocean_floor", "magma_layer"]
const BIOME_PATCH := {
	"surface_plains": "Ember", "underground_mines": "Ore", "crystal_caverns": "Crystal",
	"sky_islands": "Feather", "ocean_floor": "Scale", "magma_layer": "Core",
}

# Every milestone in display order: [{ "name", "rule", "unlocked" }].
static func milestones(codex: Dictionary) -> Array:
	var n := codex.size()
	var out: Array = []
	out.append({ "name": "Prime Lens", "rule": "First Prime recorded", "unlocked": n >= 1 })
	for biome: String in BIOME_ORDER:
		var ids := creatures_in(biome)
		var have := ids.filter(func(id: String) -> bool: return codex.has(id)).size()
		out.append({ "name": "%s Prime Patch" % BIOME_PATCH[biome],
			"rule": "%s Primes %d/%d" % [biome_name(biome), have, ids.size()],
			"unlocked": ids.size() > 0 and have >= ids.size() })
	out.append({ "name": "Prime Satchel", "rule": "any 9 Primes %d/9" % mini(n, 9), "unlocked": n >= 9 })
	out.append({ "name": "Chimera Prime Coat", "rule": "all 18 Primes %d/18, with a prismatic dash trail and the Prime Warden title" % mini(n, 18),
		"unlocked": n >= 18 })
	return out

static func unlocked_names(codex: Dictionary) -> Array:
	return milestones(codex).filter(func(m: Dictionary) -> bool: return m["unlocked"]).map(
		func(m: Dictionary) -> String: return m["name"])

# Creature ids of a biome, in data order.
static func creatures_in(biome: String) -> Array:
	var ids: Array = []
	for id: String in ordered_creatures():
		if str(ElementDB.get_enemy_data(id).get("biome", "")) == biome:
			ids.append(id)
	return ids

# All 18 creature ids in CHIMERA file order.
static func ordered_creatures() -> Array:
	var ids: Array = ElementDB.enemies.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return file_number(a) < file_number(b))
	return ids

static func file_number(creature_id: String) -> int:
	var lore := str(ElementDB.get_enemy_data(creature_id).get("lore", ""))
	var m := RegEx.create_from_string("#(\\d+)").search(lore)
	return int(m.get_string(1)) if m else 999

# The animal a creature began as, from its file note ("Black bear fused...",
# "Once a cane toad..."). "" if the file does not say.
static func base_animal(creature_id: String) -> String:
	var lore := str(ElementDB.get_enemy_data(creature_id).get("lore", ""))
	var re := RegEx.create_from_string("^CHIMERA File #\\d+\\. (?:Once an? )?([A-Za-z' -]+?)(?: fused| with| bred|\\.|,)")
	var m := re.search(lore)
	if m == null:
		return ""
	var animal := m.get_string(1).strip_edges()
	return animal.left(1).to_upper() + animal.substr(1)

static func biome_name(biome: String) -> String:
	return biome.replace("_", " ").capitalize()
