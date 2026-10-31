# Starling — Orbital Salvage

A complete **Godot 4.6+** arcade salvage game. Take one ship through a three-sector
expedition: recover energy cores, bank cargo at the safe dock, and build a ship
that can make it through the storm. A full expedition takes roughly 2–4 minutes.

## Play

1. Install [Godot 4.6 or newer](https://godotengine.org/download/).
2. Import `project.godot` in the project manager.
3. Press **F5**, then **Enter** or click **Launch Expedition**.

```sh
godot --path .
```

| Control | Action |
| --- | --- |
| WASD / arrows | Move |
| Space | Dash; shatter rocks and sentries for bonus points |
| E | Ion pulse: scatter rocks, stun sentries, pull in nearby cores |
| Esc / P | Pause / resume |
| 1 / 2 / 3 | Install an upgrade at the sector dock |
| Enter | Launch / resume / play again |
| R | Restart from a result screen |
| M | Toggle sound; preference is saved |
| F2 | Toggle reduced motion; preference is saved |

Switching away from the game pauses it automatically. Reduced motion disables
camera shake and shield flicker, reduces particles, and uses fading pulse rings.

## The expedition

| Sector | Cargo quota | Clock | What changes |
| --- | --- | --- | --- |
| The Quiet Belt | 8 cores | 65 seconds | Learn banking, pickup chains, and dash attacks |
| Broken Relay | 10 cores | 65 seconds | Sentries mark a direction, then lunge |
| The Stormfront | 12 cores | 70 seconds | Meteor lanes warn before a fast crossing |

Collect the gold canisters and return to the central dock. Stay inside its ring
for **0.7 seconds** to bank everything aboard. You can make several deliveries;
you do not have to carry the whole quota at once. Cargo slightly reduces cruising
speed. The small navigation chevron points toward a core or recommends returning
home with a larger haul. Rocks and sentries keep clear of the safe dock.

Collect another core within **4.5 seconds** to maintain a chain. Every third
pickup increases the multiplier, up to **x4**. Getting hit or letting the timer
expire breaks the chain. Banked cores stay banked, and taking damage does not
remove cargo.

Dashing grants immunity for 0.18 seconds and shatters rocks or sentries on contact.
The ion pulse scatters debris, disables nearby sentries for four seconds, pulls
nearby cores toward you, and can deflect a live meteor. It also grants a brief
0.35-second shield so the pulse has time to clear overlapping hazards.

After banking the sector quota, choose one free upgrade. The next sector repairs
one hull point. **Upgrades last for the current expedition**; a new run starts
with a fresh ship and a different opportunity to build it.

| Upgrade | Benefit per level |
| --- | --- |
| Tractor Array | +65 core attraction range |
| Twin Capacitors | −0.3 seconds dash recharge, +8% cruising speed |
| Reinforced Hull | +1 maximum hull and an extra point of repair |
| Ion Resonator | +65 pulse range, −1 second pulse recharge |

The first dock offers salvage, movement, or hull improvements. The second lets
you specialize that choice, add pulse control, or branch into survival/mobility.
Complete all three sectors to finish the expedition.

## Scoring and saves

- Core pickup: **100 × current multiplier**.
- Banking: **50 per delivered core**.
- Shattered rock: **75**. Shattered sentry: **150**. Deflected meteor: **100**.
- Sector landing: **10 per whole second remaining + 150 per remaining hull point**.
- Final ranks: **S** at 12,500, **A** at 9,500, **B** at 7,000, otherwise **C**.

Best score, completed expeditions, run count, sound, and motion preferences are
saved in `user://starling.cfg`. Earlier versions' best scores remain compatible.

## Project layout

```text
scenes/main.tscn         Entry scene
scripts/game.gd         Coordinates world, expedition, input, and transitions
scripts/expedition.gd   Sector definitions, upgrades, cargo, chains, and scoring
scripts/profile.gd      Local records and settings
scripts/pilot.gd        Movement, dash, pulse, hull, and ship drawing
scripts/core.gd         Collectible attraction and pickup detection
scripts/debris.gd       Drifting hazards and dash destruction
scripts/drone.gd        Telegraph / lunge / stun behavior
scripts/meteor_storm.gd Warned meteor lanes and deflection
scripts/arena.gd        Backdrop, dock visualization, and navigation chevron
scripts/effects.gd      Bounded particles, shockwaves, and score callouts
scripts/hud.gd          In-flight status and tutorial notices
scripts/screens.gd      Title, pause, upgrade selection, and result screens
scripts/ui_style.gd     Shared native UI styling
scripts/sound.gd        Synthesized effects and pickup-chain pitch changes
```

Tune sector quotas, time, enemies, and upgrade offers in `expedition.gd`. Tune
movement and starting ability strengths in `pilot.gd`. Gameplay coordinates use
a 1280 × 800 canvas that scales with the window and preserves its aspect ratio.
The game needs no addons, network services, Blender installation, or export
templates to play in the editor.

## Artwork and Blender models

- `assets/art/menu_backdrop.png`: built-in ImageGen menu artwork.
- `assets/art/arena_backdrop.png`: built-in ImageGen gameplay environment.
- `assets/art/ship.png`, `asteroid.png`, `energy_core.png`, `drone.png`: transparent Blender-rendered gameplay sprites.
- `assets/models/starling_assets.blend`: editable scene containing all four models.
- `assets/models/*.glb`: portable 3D exports of each model.
- `tools/build_models.py`: reproducible model construction, materials, lighting, export, and rendering.
- [Art notes and complete ImageGen prompts](assets/ART_NOTES.md).

Created and verified with Blender 5.2. To rebuild the models and sprite renders:

```sh
blender --background --factory-startup --python tools/build_models.py
```

Automatic `.blend` import is disabled so Godot users do not need Blender. The GLB
exports can be used if you want to turn the game into a 3D project.

## Verification

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd
```

The integration suite uses real input events and physics overlaps to exercise the
full three-sector expedition, pickup chains, cargo banking, dash attacks, pulse,
sentry telegraphs/stuns, meteor warnings/deflection, upgrade choices, repairs,
pause, victory, failure, restart, settings, and legacy-save compatibility. It uses
a separate temporary profile and never writes the player's save.

Omit `--headless` to also capture title, abilities, upgrade, sector, pause, result,
and smaller-window views as `/tmp/starling-v2-*.png`.

For a hands-on native playtest using a separate save profile:

```sh
godot --path . --maximized --script tools/native_playtest.gd
```

The maximized launch also avoids stale initial window captures observed during
native macOS computer-use testing. If an existing window shows an old frame,
zooming the window refreshes it. The test profile never changes player records.
