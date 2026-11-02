# Systems & Player-Interaction Review — saving, menus, management, storage

**Date:** 2026-11-02 · **Status:** review and proposal; nothing here is built yet except where stated.
Method: read the code, then drove the running game headless (key presses, file checks).
References: the games on our reference board and from chat (Golden Sun, Zelda, Octopath
Traveler, Dragon Quest, Chrono Trigger, Digimon World, Genshin, Hades) plus Minecraft.

---

## 1. What the game does today (verified)

| Area | Today | Problem |
|---|---|---|
| **Loading** | `SaveSystem.load_game()` exists but **nothing calls it**. There is no title screen or Continue. | Every launch is a new game. Saves are written and never read. |
| **Saving** | `X` writes one slot (`user://savegame.json`) anywhere, any time, with no on-screen confirmation (it only prints to the console). | One slot, no feedback, easy to hit by accident, no autosave. |
| **World seed** | `world.gd` uses `noise.seed = randi()` and the seed is not saved. | Once loading is added, saved dug tiles and position would land in a *different* world. |
| **Bosses / Wardens** | Defeat state is not saved. | Bosses would be back after loading. |
| **Compendium** | Discoveries are saved but not restored on load. | Progress lost. |
| **Crafting** | The 3×3 grid exists, but **no key opens it**: `C` only toggles the Compendium and nothing calls `toggle_crafting()`. | The core loop (craft weapons, armour, the Resonance Engine) is unreachable without the Synthesizer. |
| **Closing menus** | Only the journal (E) and the quiz close on Esc. The Compendium, crafting and Synthesizer do not. | Players get stuck; inconsistent. |
| **Pausing** | The journal pauses the game; dialogue and the quiz explicitly do not. | You can be hit while reading. |
| **Menus overall** | Journal (E), Compendium (C), Synthesizer (F at machine), quiz (F at desk), dialogue. No pause menu, no options. | AudioManager has volume and mute APIs, but no screen exposes them. |
| **Storage** | Elements cap at 9,999 g, consumables at 99, key items unlimited; lab containers are used up one per sample. | Nothing creates carrying pressure, so a storage chest would have no purpose yet. |

---

## 2. What the reference games teach

| Game | Pattern worth taking | Why it fits us |
|---|---|---|
| **Golden Sun** | Save from the menu almost anywhere; three slots shown as cards. | Low friction for a handheld-style top-down RPG. |
| **Zelda (Minish Cap / BotW)** | Manual save plus autosave at meaningful moments; respawn near where you fell. | We already respawn Zelda-style; autosave completes it. |
| **Octopath / Dragon Quest** | Save points that also heal (inns, statues) **and** a one-off *quick save* anywhere to resume later. | Classroom play ends when the bell rings: suspend-anywhere is essential. |
| **Chrono Trigger** | Save points before big fights. | Natural before boss arenas. |
| **Octopath 0 / DQ XI** | One book-like menu hub with a contents list on the left. | We already have the journal; make it the hub for everything. |
| **Genshin** | Category tabs, "new" badges, sort order, rarity at a glance. | Players can find new loot fast. |
| **Digimon World** | Item storage at a town bank. A cautionary tale: tight carry limits plus trips to the bank were the most tedious part. | Avoid storage busywork unless it earns its place. |
| **Hades** | No menu-diving mid-fight; everything usable in combat is on a button. | Our dash combat needs quick slots, not a paused book. |
| **Minecraft** | Autosave; a persistent world from a saved seed; a **recipe book** that shows discovered recipes and fills the grid for you; a **hotbar**; crafting tables; chests. | The game *is* "collect elements, combine them": the recipe book doubles as the learning tool. |

---

## 3. Recommendations

### 3.1 Saving: three layers, never lose progress
1. **Title screen:** Continue · New Game · Load · Options. **Three save slots** shown as journal
   cards: Orion portrait, biome, play time, Ashmarks, Codex %, date.
2. **Field Stations** (one per biome, plus Ashvale): a lab tent or bench. Manual save, full heal,
   and later fast travel between stations (Octopath inns plus DQ statues, in our science flavour).
   One sits outside every boss arena (Chrono Trigger rule).
3. **Autosave** to a separate *Autosave* slot, so it never overwrites a manual save: on entering a
   biome, after a Warden, after a boss, after crafting a key item, and every 5 minutes.
4. **Suspend** from the pause menu anywhere: saves and quits to the title. The suspend file is
   consumed on resume (it doesn't replace real saves). This is the classroom-bell button.
5. Persist what is missing: **world seed**, defeated bosses, Wardens and fragments, compendium
   discoveries, the Prime Codex (already saved) and Boss Keys (already saved).
6. **Feedback:** a small book-and-quill toast, "Journal saved", for every save, including autosave.
7. **Web build:** browser saves live in site storage and vanish if it is cleared. Add
   **Export / Import save** (a downloadable file or copyable code) on the Load screen.
8. Retire the bare `X` hotkey, or keep it only as a quick save that shows the toast.

### 3.2 One menu hub: the journal
Esc (or Start) opens the journal at a **Contents** page (Octopath's left-hand menu list):

| Section | Contents |
|---|---|
| Items | Elements · Equipment · Consumables · Key Items (built) |
| Crafting | The 3×3 grid plus the Recipe Book (3.3) |
| Compendium | The periodic table of discovered elements |
| Bestiary | CHIMERA files for each creature met, plus the Prime Codex progress |
| Journal | Story notes, current objective, Wardens found per biome |
| Map | Biomes, Field Stations, marked Warden and boss sites |
| Options | Music / SFX volume, text speed, controls, accessibility |
| Save & Quit | Save (only at a Field Station), Suspend, Quit to Title |

Direct keys still jump straight to a page: **E** items, **C** compendium, **R** crafting (new),
**M** map. Same key or Esc closes. **Only one menu open at a time**, and **every menu pauses**,
including dialogue and the quiz (text advances on a key, so pausing costs nothing).

### 3.3 Management: borrow Minecraft where the game *is* Minecraft
- **Fix crafting access first** (bug).
- **Recipe Book** beside the crafting grid: every recipe the player has the elements for is
  listed with its formula and a short fact. Clicking it fills the grid. Locked recipes show as
  silhouettes with a hint ("needs a halogen"). This is the biggest usability and learning win.
- **Two crafting tiers:** a 2×2 pocket grid anywhere for simple compounds; the full 3×3 only at
  benches (Aldric's workshop and Field Stations). The same rule as Minecraft's table.
- **Quick slots (hotbar):** four slots on the HUD for consumables and the Boss Key, used with
  1–4 (or D-pad) without pausing. The journal stays for planning; the hotbar is for fighting.
- **Equipment compare:** before equipping, show stat changes in green or red (JRPG standard).
- **"New" badges and sorting** in the journal (Genshin): sort by recent, name or type; a dot on
  ribbons that hold unseen items.
- **Containers warning:** when standing at an ore tile, the HUD shows whether you can collect it
  and which container it will use; warn when vials run low. Today this rule is invisible.

### 3.4 Storage: don't add busywork
With no carry limits there is nothing to store, and Digimon World shows how tedious bank trips
get. **Recommendation: no general storage chest for now.** Two optional, purposeful kinds instead:
- **Specimen Cabinet** in Aldric's workshop: display trophies (shiny and Prime drops, boss
  relics, the Prime set) as a museum wall. Pride, not logistics.
- **Chests only if the building system returns** (Phase 5). Then they come with it, Minecraft-style.

### 3.5 Death and difficulty (Minecraft vs JRPG)
Keep today's kid-friendly rule (keep everything, respawn in Ashvale) for normal play. Add it to
Options as **Keep Inventory: on**; Unkeyed / hard players can switch it off to drop half their
Ashmarks where they fell (Minecraft-style recovery run).

---

## 4. Suggested order

| Priority | Work | Size |
|---|---|---|
| **P0 (bugs)** | Make crafting reachable · Esc closes every menu · every menu pauses · save the world seed, defeated bosses and compendium · save toast | Small |
| **P0** | Title screen with Continue / New / Load, 3 slots, and actually loading saves | Medium |
| **P1** | Autosave slot · Suspend · Field Stations (save and heal) | Medium |
| **P1** | Journal Contents hub · Options page (volume, controls) | Medium |
| **P1** | Recipe Book · hotbar quick slots | Medium |
| **P2** | Fast travel between stations · equipment compare · new badges and sorting · container warnings | Medium |
| **P2** | Save export / import for the web build · Specimen Cabinet | Small |
