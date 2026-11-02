extends Node

# EncounterSystem — autoload. Decides each new enemy's rarity and tracks the
# Prime Codex (one super-rare Prime form per CHIMERA creature; collect all 18).
#
# Every enemy spawned counts as one encounter. Rarities are rolled rarest first:
#   prime  — 1 in 1000   (codex collectable)
#   shiny  — 1 in 100    (special loot)
#   strong — 1 in 10     (bigger footprint, tougher, double drops)
# Bad-luck protection: if a rarity has not appeared for PITY_MULT × its rate,
# the next encounter is guaranteed to be that rarity. Counters persist in saves.

signal rare_spawned(creature_id: String, rarity: String)
signal prime_recorded(creature_id: String, collected: int, total: int)
signal prime_codex_completed

const RATES := { "prime": 1000, "shiny": 100, "strong": 10 }
const ROLL_ORDER := ["prime", "shiny", "strong"]
const PITY_MULT: int = 2

var encounters: int = 0
var since_last: Dictionary = { "prime": 0, "shiny": 0, "strong": 0 }
var defeated_by_rarity: Dictionary = { "normal": 0, "strong": 0, "shiny": 0, "prime": 0 }
var prime_codex: Dictionary = {}   # creature_id -> true
var codex_completed: bool = false

# Rolls the rarity for one new encounter. `roll` lets tests inject randomness.
func roll_rarity(creature_id: String = "", roll: Callable = Callable()) -> String:
	encounters += 1
	for r: String in ROLL_ORDER:
		since_last[r] = int(since_last.get(r, 0)) + 1
	for r: String in ROLL_ORDER:
		var rate: int = RATES[r]
		var value: float = roll.call() if roll.is_valid() else randf()
		if int(since_last[r]) >= rate * PITY_MULT or value < 1.0 / rate:
			since_last[r] = 0
			if creature_id != "":
				rare_spawned.emit(creature_id, r)
			return r
	return "normal"

func record_defeat(creature_id: String, rarity: String) -> void:
	defeated_by_rarity[rarity] = int(defeated_by_rarity.get(rarity, 0)) + 1
	if rarity != "prime" or prime_codex.has(creature_id):
		return
	prime_codex[creature_id] = true
	var total: int = ElementDB.enemies.size()
	prime_recorded.emit(creature_id, prime_codex.size(), total)
	if not codex_completed and prime_codex.size() >= total:
		codex_completed = true
		prime_codex_completed.emit()

func serialize() -> Dictionary:
	return {
		"encounters": encounters,
		"since_last": since_last.duplicate(),
		"defeated_by_rarity": defeated_by_rarity.duplicate(),
		"prime_codex": prime_codex.keys(),
		"codex_completed": codex_completed,
	}

func deserialize(d: Dictionary) -> void:
	encounters = int(d.get("encounters", 0))
	var since: Dictionary = d.get("since_last", {})
	for r: String in ROLL_ORDER:
		since_last[r] = int(since.get(r, 0))
	var defeated: Dictionary = d.get("defeated_by_rarity", {})
	for r: String in defeated_by_rarity:
		defeated_by_rarity[r] = int(defeated.get(r, 0))
	prime_codex.clear()
	for id in d.get("prime_codex", []):
		prime_codex[str(id)] = true
	codex_completed = bool(d.get("codex_completed", false))

func reset() -> void:
	deserialize({})
