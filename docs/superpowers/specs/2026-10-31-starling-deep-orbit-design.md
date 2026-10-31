# Starling: Deep Orbit — roadmap and Phase 1 design

Status: approved for implementation (design calls delegated to the agent; marked *agent's call*).

## Fiction and intent

You fly salvage for **The Roost**, a patched-together hangar station parked in a
dead shipping lane. Every core you bank keeps the lights on — and slowly rebuilds
the station. Far below the lane, at the bottom of a gravity well, drifts the wreck of
the **Leviathan**, a colossal ore hauler whose reactor still beats. Reaching it is
the long-term goal of a player's first evening with the game.

Today Starling is a tight 2–4 minute arcade run with upgrades that vanish at the end.
There is no reason to play run #6 that run #2 didn't give you. Phase 1 adds:

1. **A meta loop** — persistent Scrap, a Workshop of permanent unlocks, ship frames,
   and a home hub (The Roost) that visibly grows as you invest.
2. **A deeper run loop** — a 10-card upgrade draft instead of 4 fixed choices.
3. **A 3D expansion** — a full 3D presentation of the game, and a new 3D-first
   route, **Deep Orbit**, with new mechanics and a boss.

Success: a player finishes a Survey run, sees exactly what their Scrap buys, wants
the next unlock, and eventually reaches and silences the Leviathan. Flying in 3D
reads as clearly as the 2D game.

### Goals
- Every run (win or lose) pays Scrap, and the result screen shows progress toward the next unlock.
- The Roost hub is a live 3D scene: the selected ship on the pad, station modules appearing per purchase.
- Deep Orbit: 4 sectors, 3 new mechanics (spires, gravity well, Leviathan boss).
- The 3D view works on both routes. The Survey route can toggle between 2D and 3D (F3).

### Non-goals (this phase)
Multiplayer, online services, controller support, music tracks, contracts/modifiers,
cosmetics, and endless mode. These are on the roadmap below.

### Anti-goals (failure even if it "works")
- 3D that hurts readability: hazards, telegraphs, and the dock must read at a glance.
  The whole play field stays on screen; there is no camera that hides threats.
- Breaking the Survey route's feel, its tests, or existing saves (legacy `starling.cfg` must load).
- Grind: one evening (~10–15 runs) should unlock nearly everything.
- Below 60 fps on an Apple Silicon MacBook Air, or adding a runtime Blender dependency.

## Constraints
- Godot 4.6+ (CI uses 4.7.2), **GL Compatibility renderer** (keep it; universal macOS export).
- Synthesized sound only (extend `sound.gd`); no new audio files.
- The game keeps working with no addons or network access.

## Architecture (decided)
**The simulation stays 2D. The 3D is a presenter.** Gameplay keeps running on the
existing Area2D actors in the 1280 × 800 coordinate space. A new 3D view reads the
simulation each frame and mirrors every actor with a GLB model on the XZ plane. This
means:
- Existing tests and rules stay valid. New mechanics are added as 2D sim nodes.
- F3 can switch views at any moment. The 2D actors are hidden, not removed, in 3D mode.
- Effects (bursts, waves, callouts) and the navigation chevron must line up with
  the 3D view (project through the camera, or render natively in 3D; *builder's call*).
- `Expedition` stays a pure rules object, now route-aware. Meta state lives in `FlightProfile`
  (or a new `Workshop` rules class it persists).

## Phase 1 design

### Routes
| Route | Sectors | View | Unlock |
| --- | --- | --- | --- |
| SURVEY ROUTE | The existing 3 sectors, unchanged | 2D by default, F3 toggles 3D | Always |
| DEEP ORBIT | 4 new sectors (below) | Always 3D | Workshop "Deep Orbit Charts" (250), or free on the first Survey victory |

Deep Orbit sectors (*agent's call*, tune freely after playtesting):

| # | Sector | Quota | Clock | Rocks | Sentries | Feature |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | THE SHELF | 9 | 65 s | 7 | 1 | Introduces flying in 3D at the lip of the well |
| 2 | FOUNDRY SPIRES | 10 | 70 s | 6 | 2 | 5 solid refinery spires |
| 3 | THE WELL | 11 | 70 s | 7 | 1 | Gravity well plus meteor storm |
| 4 | THE LEVIATHAN | 12 | 80 s | 4 | 0 | Boss |

- **Spires:** static circular obstacles (radius ~34 px), kept clear of the dock and spawn points.
  The ship slides along them and is not damaged. Rocks bounce off them. A dash cannot break
  them. Cores never spawn inside them. In 3D they are tall towers that cast real shadows.
- **Gravity well:** a sink placed off-center, away from the dock. It pulls the pilot (up to ~260 px/s²,
  falling off to zero at radius ~330) and slowly drags loose cores. Touching the event
  horizon (r ~40) deals 1 damage and flings the ship outward. Any core that reaches the horizon is
  consumed and respawns elsewhere. **Ion pulse inverts the well for 1.5 s** so it pushes instead of pulls,
  which gives the pulse a second job.
- **The Leviathan:** a huge derelict hulk that slowly patrols a wide ellipse around the arena's
  upper band. It has 3 glowing **vents**. Touching its hull without dashing deals damage, and a
  dash bounces off. **Dashing into a vent cracks it**: +400 score and 3 cores spill out. It sheds one
  core every ~8 s. Every ~6 s it telegraphs a **beam lane** (1.4 s amber warning, then a 0.6 s
  damaging beam), styled after the meteor-lane warnings so the language is shared. Cracking all
  3 vents gives **LEVIATHAN SILENCED**: +1500 and the beams stop. Banking the quota wins the route.
  6 cores start in the field.
- Deep Orbit rank thresholds: S 18 000, A 14 000, B 10 000. Docks between sectors work as
  before, with +1 hull repair.

### Upgrade draft (run loop)
At each dock, offer **3 distinct cards** drawn from the *unlocked* pool, using levels below 2 (max level 2).
Draws come from an expedition RNG seeded at run start, so tests stay deterministic. When possible,
at least one offer is a card you already own, so the old "specialize or branch" feel survives.

| Card | Tag | Per level | Unlocked by |
| --- | --- | --- | --- |
| Tractor Array | SALVAGE | existing | default |
| Twin Capacitors | MOBILITY | existing | default |
| Reinforced Hull | SURVIVAL | existing | default |
| Ion Resonator | CONTROL | existing | default |
| Chain Battery | COMBO | +1.5 s chain window; lvl 2 also raises multiplier cap to x5 | Workshop 120 |
| Ballast Dampers | HAULING | no cargo slowdown; −0.2 s bank time | Workshop 120 |
| Chronometer | TIME | +8 s to every later sector clock | Workshop 150 |
| Ram Plating | ASSAULT | +0.1 s dash immunity; each dash-shatter adds +1.5 s to the clock | Workshop 150 |
| Salvage Wing | ESCORT | a companion drone orbits (~70 px) and collects cores it touches; lvl 2 = two wings | Workshop 220 |
| Overdrive Core | CONTROL | every 6th pickup in a chain (every 4th at lvl 2) fires a free pulse | Workshop 220 |

### Ship frames
| Frame | Hull | Speed | Dash recharge | Magnet | Notes | Unlock |
| --- | --- | --- | --- | --- | --- | --- |
| STARLING | 3 | 1.00 | 1.3 s | 45 | balanced | default |
| KESTREL | 2 | 1.15 | 1.0 s | 45 | smaller hitbox (r 11) | Workshop 300 |
| ALBATROSS | 4 | 0.88 | 1.5 s | 80 | cargo slowdown halved | Workshop 300 |

### Scrap and the Workshop (meta loop)
Run payout, paid on win **or** loss:
`scrap = (total_banked × 8 + sectors_cleared × 40 + (150 if won)) × route_mult × broker_mult`.
`route_mult` is 1.0 for Survey and 1.25 for Deep Orbit. `broker_mult` is 1 + 0.15 × Scrap Broker level.
A Survey win pays about 500, and an early loss pays about 40.

| Workshop item | Cost | Effect | Roost module that appears |
| --- | --- | --- | --- |
| Deep Orbit Charts | 250 | unlock Deep Orbit | long-range antenna dish |
| Kestrel Frame | 300 | frame | hangar arm A |
| Albatross Frame | 300 | frame | hangar arm B |
| 6 card schematics | 120–220 | add a card to the draft pool | fabricator rack (one light per schematic) |
| Hull Plating | 250 | +1 starting and max hull (permanent) | armor ring |
| Scrap Broker I / II | 180 / 300 | +15 % scrap per level | trade beacon |
| Launch Rig | 350 | start each run with one random unlocked card at level 1 | launch rail |

### The Roost hub (title screen)
This replaces the static title panel. It keeps the left-hand UI panel style (`ui_style.gd`). The
right side shows a live 3D scene: the Roost station with the selected frame on its pad, slowly
turning. Station modules appear for every Workshop purchase. Sections: **Launch** (route and
frame selection), **Workshop** (buy items, with costs, owned state, and Scrap balance),
**Records** (best per route, runs, victories). It must be fully usable by mouse *and*
keyboard (Enter still launches). The result screen shows Scrap earned and progress toward the cheapest locked item.

### Preview flag
`godot --path . -- --unlock-all` uses a **separate** temporary profile with everything
unlocked and 5000 Scrap, so the full expansion can be seen without grinding. It never touches the real save.

## Asset contract (Blender → Godot)
All assets live in `assets/models/` and are built by `tools/build_deep_orbit_models.py`. Each one is a GLB
in the same beveled hard-surface style and palette as `tools/build_models.py`: ivory, graphite, mint,
rescue orange, and amber glow. 1 Blender unit = 1 m. Nose along Blender +Y, which becomes Godot −Z. Top is +Z,
and the origin sits at the footprint center. Existing `ship.glb` is ~2.7 wide × 3.8 long.

| File | What | Approx size | Required child node names |
| --- | --- | --- | --- |
| `kestrel.glb` | slim, fast frame, swept wings, one large engine | like ship | — |
| `albatross.glb` | wide heavy hauler, cargo pods, four engines | 1.3× ship | — |
| `salvage_wing.glb` | tiny companion drone | 0.8 | — |
| `dock_beacon.glb` | in-sector safe dock: landing pad and emissive mint ring | 4 diameter | `Ring` |
| `roost_station.glb` | hub station: core ring, docking pad, modules | ~16 across | `Pad`, `Module_Charts`, `Module_Kestrel`, `Module_Albatross`, `Module_Fabricator`, `Module_Plating`, `Module_Broker`, `Module_Rig` |
| `meteor.glb` | molten meteor with emissive cracks | 1.6 | — |
| `asteroid_b.glb`, `asteroid_c.glb` | rock variants | like asteroid | — |
| `foundry_spire.glb` | tall refinery pylon with orange lights | 3 wide × 12 tall | — |
| `gravity_well.glb` | collapsed-star sink with an emissive accretion ring | 8 diameter | `Ring` |
| `leviathan.glb` | colossal derelict ore hauler | ~30 long | `Vent_0`, `Vent_1`, `Vent_2` (on the top hull) |

There are also renders in `assets/art/`: `deep_orbit_sky.png` (2:1 equirect panorama, deep navy, a pale
planet curve below, faint nebula), 256 px RGBA thumbnails of `kestrel`, `albatross`, and
`salvage_wing` for UI, and a `deep_orbit_lineup.png`. The code falls back to existing GLBs
or primitives if an asset is missing.

## Roadmap
- **Phase 1: Deep Orbit (this build).** Meta loop, Workshop, frames, card draft, 3D presenter, Roost hub, Deep Orbit route, and the Leviathan.
- **Phase 2: Contracts.** Pre-launch modifiers that trade risk for Scrap: *Heavy Haul* (+50 % quota, ×1.5 scrap),
  *Silent Running* (no pulse, ×1.4), *Storm Chaser* (meteors in every sector, ×1.3). Adds a seeded **daily expedition** and local per-route boards.
- **Phase 3: The Living Roost.** Hangar crew who comment on your runs, restoring station decks
  as a long Scrap sink, and **Relic Cores** that unlock lore logs about the Leviathan's crew.
- **Phase 4: Feel and reach.** Gamepad support, rebinding, adaptive synth music that layers with the chain multiplier,
  Steam Deck verification, and colorblind telegraph palettes.
- **Phase 5: Drift.** An endless descent mode down the well with escalating sectors, hull paints earned from S ranks, and a ghost of your best run.
