# Boss Fights, Boss Keys and Progression Gear — Design

**Status:** approved direction, 2026-11-02 (D-016). Not yet built. Numbers are first-pass and will be tuned in playtest.
Builds on D-011 (mythical bosses), D-014 (enemy rarity) and D-015 (dash, huge bosses).

Every counter-tool and every reward below is grounded in real chemistry, so beating a boss
teaches the reaction that beats it.

---

## 1. The loop for each level

```
explore biome ─► defeat 3 Wardens ─► 3 Key Fragments ─► combine at Synthesizer
      ▲                                                        │
      │                                                        ▼
next biome ◄── boss drops Unique Gear ◄── defeat boss ◄── Boss Key opens arena
```

1. **Wardens.** Each biome has 3 fixed Warden spots, one per creature type in that biome. A Warden
   is a guaranteed *strong* (D-014) version of that creature with an escort of 2–3 normal ones.
   Each Warden drops one **Key Fragment**. Wardens do not respawn once beaten; their spots are
   marked on the minimap.
2. **Boss Key.** The 3 fragments combine at the Synthesizer into the level's **Boss Key**. The key
   does two jobs:
   - **Entrance:** it unseals the boss arena. The key is **required**; the only other way in is
     the Formula Gate sequence (section 1a).
   - **Counter-tool:** during the boss's vulnerable windows (section 3), pressing *Use Tool* applies
     the counter-reaction for a guaranteed stagger and bonus damage. Each key has 3 charges per
     fight; the fight can be won without using them, but much more slowly.
3. **Unique Gear.** The boss drops one piece of gear built for the *next* level. It is optional:
   a skilled player can push on without it, but it is the intended path for players following
   the story.

### 1a. The Formula Gate (hard-mode easter egg)

Each sealed arena gate is ringed with element runes. Striking the runes in the order of the
boss's formula, written out atom by atom, opens the gate without a key:

| Boss | Sequence | Hint (found in the world) |
|---|---|---|
| Peroxis | Na · Na · O · O | A scorched lab note: "two of the salt, two of the breath" |
| Chalcor | Cu · Fe · S · S | A miner's chalk tally on the Warden cave wall |
| Aurium | H · Au · Cl · Cl · Cl · Cl | Scratched into a gold-flecked crystal: "one servant, one king, four guards" |
| Azrael | Na · N · N · N | A torn airbag recall notice on Sky Island 2 |
| Atacama | Cu · Cu · Cl · O · H · O · H · O · H | Barnacle pattern on the wreck's hull |
| Uranox | U · O · O | Etched on the Ouroboros Ring plinth |

- A wrong rune resets the gate and spawns a strong enemy, so guessing is costly.
- Entering this way is **Unkeyed mode**: no counter-tool charges, the boss starts in its phase-2
  attack set, and it gains +25% HP. The Boss Key's fragments still drop afterwards for completionists.
- Beating a boss Unkeyed awards the **Formula Breaker** badge for that boss (shown in the
  Compendium) and a unique goggle-lens tint. All six unlock the **Unkeyed** title.
- Knowing a compound's formula is the hard-mode skill, so the easter egg rewards exactly what the
  game teaches.

---

## 2. The six levels

### Level 1 — Surface Plains · PEROXIS (Na₂O₂, manticore)

| | |
|---|---|
| **Wardens → fragments** | Ashburn Shambler → *Carbon Ember* · Carbon Crawler → *Pressure Valve* · Potash Poltergeist → *Canister Shell* |
| **Boss Key** | **CO₂ Canister**. Sodium peroxide scrubs carbon dioxide (2Na₂O₂ + 2CO₂ → 2Na₂CO₃ + O₂), which is how submarines and spacecraft clean their air. Sprayed into Peroxis's core, it turns the reactive crystal into inert soda ash. |
| **Reward (item 1)** | **Peroxide Crossbow**, the first ranged weapon. Fires crystal bolts that burst into a small caustic puff. Needed for the Mines, where Chalcor's shockwaves punish anyone who stays close. |

### Level 2 — Underground Mines · CHALCOR (CuFeS₂, hoard dragon)

| | |
|---|---|
| **Wardens → fragments** | Iron Hulk → *Frother Flask* · Copper Coil → *Collector Crystal* · Zinc Phantom → *Bellows Core* |
| **Boss Key** | **Flotation Charge**. Real copper mines separate chalcopyrite from rock by *froth flotation*: bubbles carry the ore up and leave the waste behind. The charge foams over Chalcor's plates and strips its fool's-gold armour. |
| **Reward (item 2)** | **Tarnish-Lens Goggles**. Cut from Chalcor's iridescent tarnish, they light up the dark Crystal Caverns, reveal hidden crystal paths and halve blind duration (Aurium's ruby cloud blinds). |

### Level 3 — Crystal Caverns · AURIUM (HAuCl₄, three-headed hydra)

| | |
|---|---|
| **Wardens → fragments** | Silver Specter → *Citrate Phial* · Gold Golem → *Heating Coil* · Prismatic Hound → *Prism Lens* |
| **Boss Key** | **Reducing Lance**. Heating chloroauric acid with citrate reduces it to solid gold nanoparticles (the Turkevich method, still used in medical tests). Each lance strike solidifies one hydra neck into dead gold. |
| **Reward (item 3)** | **Gilded Storm Mantle**, weather armour for the Sky Islands. Spacecraft use thin gold film because it reflects radiation and never corrodes; the mantle also grounds lightning and resists wind knockback (wind columns, Static Djinn, Stormwing). |

### Level 4 — Sky Islands · AZRAEL (NaN₃, white phoenix)

| | |
|---|---|
| **Wardens → fragments** | Alkali Hawk → *Nitrite Salt* · Static Djinn → *Acid Ampoule* · Stormwing → *Storm Feather* |
| **Boss Key** | **Nitrite Flask**. Labs safely destroy leftover sodium azide with sodium nitrite and acid, which turns it into harmless nitrogen gas. Each dose defuses one of Azrael's stored detonation charges. |
| **Reward (item 4)** | **Inflation Dive Rig**, the water-access tool for the Ocean Floor. Built from Azrael's azide capsule: the same reaction that inflates a car airbag in 30 ms fills a buoyancy bladder, letting Orion dive, surface and breathe in the flooded level. |

### Level 5 — Ocean Floor · ATACAMA (Cu₂Cl(OH)₃, leviathan)

| | |
|---|---|
| **Wardens → fragments** | Brine Crawler → *Zinc Ingot* · Verdigris Lurker → *Copper Strap* · Deep Shocker → *Charged Coil* |
| **Boss Key** | **Sacrificial Anode**. Real ships bolt zinc blocks to their hulls: the zinc corrodes instead of the steel. Clamped to Atacama's glowing hull plate, the anode turns its own corrosion against it and the plate falls away. |
| **Reward (item 5)** | **Brine-Cooled Heat Shield** for the Magma Layer. Water stores more heat than almost any other common substance, so a jacket of circulating brine soaks up lava heat. Cancels the magma biome's ambient burn and halves fire damage. |

### Level 6 — Magma Layer · URANOX (UO₂, basilisk)

| | |
|---|---|
| **Wardens → fragments** | Uranium Wraith → *Boron Carbide Pellet* · Thorium Scorcher → *Cadmium Sleeve* · Platinum Sentinel → *Rod Housing* |
| **Boss Key** | **Control Rods**. Reactors are slowed by sliding in rods of boron or cadmium, which soak up neutrons. Each rod slotted into Uranox's crown drops it out of supercritical. |
| **Reward** | The existing **Uranium Core Fragment** (powers the Plutonium Edge and Cannon) and the final step of the story. |

**Progression summary:** Crossbow → Goggles → Storm Mantle → Dive Rig → Heat Shield → endgame.

---

## 3. Boss fight structure (arcade cycle)

Every boss runs the same readable loop, so players learn one grammar and six dialects:

```
MAIN ×2–3 ─► STRONG (telegraphed) ─► RECOVERY PAUSE ─► repeat
                                          │
                     hit during pause ────┴─► STAGGER: 3 s stunned, takes ×2 damage
                     use Boss Key  ───────────► counter-reaction: bigger stagger + bonus
```

- **Main attack:** frequent, light, dodgeable with movement alone.
- **Strong attack:** big, heavily telegraphed (a red ground marker and a distinct sound for about
  0.8 s), meant to be dashed *through*. Hades-style: invulnerable dash frames are the answer.
- **Recovery pause:** after the strong attack the boss is exposed for about 1.5 s. This is the
  window the fight is built around. Hitting the weak point during it causes a **stagger**;
  hitting it at other times does reduced damage (armour up).
- **Overdrive (HP below 25%):** a new strong attack, a faster cycle (×1.3), shorter pauses
  (about 1.0 s) and a visual change. Bosses that are not staggered in overdrive regenerate slowly,
  so players must keep hitting the pattern rather than tank it.
- The current three phases map onto this: phase 1 = main/strong at full health, phase 2 (55%) adds
  the second main attack, phase 3 (25%) = overdrive. Uranox's last threshold moves from 20% to 25%.

### Per-boss patterns

| Boss | Main attack | Strong attack (tell → dodge) | Recovery pause (weak point) | Overdrive (<25%) |
|---|---|---|---|---|
| **Peroxis** | Caustic spray cone, three bursts | Tail-sting pounce; foam puddles where it lands. Tell: crouch and tail raise | Stinger sticks in the ground, core exposed on its chest | **Supercritical:** puddles ignite (oxygen burst) and it pounces twice |
| **Chalcor** | Claw swipe plus a fan of ore shards | Sulphur-breath sweep across the arena. Tell: inhale glow | Cools down; armour plates part and the glowing copper core shows | **Copper Core Exposed:** burrows and erupts under Orion; cracks in the floor are the tell |
| **Aurium** | Acid bolts from heads in rotation (left, middle, right) | Gold Prison: an acid ring closes into a cage, dash out before it shuts | All three heads dip to drink from the acid pool; the frilled head is the weak point. Three windows sever three necks | **Ruby Cloud:** surviving heads spit blinding clouds, faster rotation |
| **Azrael** | Nitrogen-lance dive along a marked line | Airbag swell: chest inflates for 2 s, then a detonation ring | Deflated and grounded: the only safe time to hit it (hitting it while crystalline sets off a counter-blast) | **Chain Detonation:** blasts ripple around the arena in a fixed sequence that players learn |
| **Atacama** | Corrosive spit (lowers armour) | Tide surge: a wave crosses the arena; dash through the gap in the crest | Beaches itself on the wreck; one hull plate glows | **Copper Implosion:** a whirlpool pull; dash against it, core exposed at the centre |
| **Uranox** | Gamma pulse rings | Fission gaze: a sweeping beam; break line of sight behind pillars or dash through | Eyes overheat and close; the crown slots open | **Meltdown:** the radiation safe zone shrinks; slot the last control rod to scram it |

---

## 4. Loot from regular enemies

| Drop | Use | Source |
|---|---|---|
| **Ions** (currency) | Buy from Ashvale traders: potions, dyes, recipe hints | All enemies; ×2 strong, ×5 shiny, ×20 prime |
| **Biome materials** (Plains Fibre, Mine Ore, Cavern Quartz, Sky Down, Sea Glass, Magma Slag) | Upgrade weapons (+damage, +dash-strike) and armour (+resistance) at Aldric's bench; also used for appearance upgrades | Each biome's enemies; strong ones drop more |
| **Potions** | *Saline Tonic* (heal), *Buffer Solution* (clears corrode and poison), *Lead Draught* (clears irradiate) | About 1 in 8 kills |
| **Cosmetics** | Jacket patches, goggle-lens tints, coat dyes, satchel badges for Orion (D-010 style) | Shiny kills (guaranteed) and rare drops; primes drop the Prime set (4a) |

### 4a. The Prime cosmetic set (Prime Codex reward)

The Prime set is iridescent, matching the shimmer Primes have in the world. It is earned in steps,
so the 1-in-1000 hunt pays out along the way:

| Codex progress | Unlocks |
|---|---|
| First Prime recorded | **Prime Lens** goggle tint (oil-slick iridescence) |
| All 3 Primes of a biome | That biome's **Prime Patch** for the jacket (6 patches: ember, ore, crystal, feather, scale, core) |
| 9 of 18 | **Prime Satchel**: iridescent canvas with a Codex clasp |
| All 18 (Codex complete) | **Chimera Prime Coat**: the full iridescent leather jacket, plus a prismatic dash trail and the **Prime Warden** title |

All pieces are cosmetic only, so completionists stand out without unbalancing combat.

---

## 5. Open questions

1. **Warden respawn:** Wardens stay beaten once killed. Should a lost fragment ever need re-earning?
2. **Currency name:** "Ions" is a placeholder; shortlist under trial.
