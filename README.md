# Starling: Deep Orbit

A **Godot 4.7 GDScript** arcade salvage game. Fly for **The Roost**, recover energy
cores, bank them at the safe dock, and rebuild your home station with persistent
Scrap. Survey is a familiar three-sector, 2–4 minute expedition. Deep Orbit adds
four sectors, solid refinery spires, a gravity well, and the Leviathan ore hauler.

[Phase 1 design and roadmap](docs/superpowers/specs/2026-10-31-starling-deep-orbit-design.md)
cover the expansion and the planned contracts, daily expeditions, station crew,
controller support, and endless descent.

Download the standalone macOS app from [GitHub Releases](https://github.com/aranlucas/starling-orbital-salvage/releases).
The universal build supports Apple Silicon (macOS 13+) and Intel (macOS 11+).
Unzip and open `Starling.app`; the editor is only needed to develop the game.
Release builds are ad-hoc signed and are not Apple-notarized.

## Play and controls

Import `project.godot` into Godot 4.7, press **F5**, then **Enter** or click Launch.
The game needs no addons, services, export templates, or runtime Blender install.

```sh
godot --path .
# Separate temporary profile: all unlocks and 5000 Scrap, real save untouched.
godot --path . -- --unlock-all
```

| Control | Action |
| --- | --- |
| WASD / arrows | Move |
| Space | Dash; shatter rocks/sentries and crack Leviathan vents |
| E | Ion pulse: scatter rocks, stun sentries, attract cores, deflect meteors, invert the well |
| Esc / P | Pause / resume |
| 1 / 2 / 3 | Install an offered upgrade at the sector dock |
| Enter | Launch / resume / play again |
| R | Restart from a result screen |
| H | Return to The Roost from a result screen |
| L / B / T | Hub Launch / Workshop / Records section |
| Q | Switch unlocked route in the hub |
| F / left / right | Cycle unlocked ship frame in the hub |
| Up / down, then Space | Select and buy a Workshop item |
| M | Toggle sound; saved |
| F2 | Toggle reduced motion; saved |
| F3 | Toggle Survey between 2D and 3D; saved. Deep Orbit always uses 3D |

Every hub action also has a mouse button. Enter launches from every hub section.
Switching away automatically pauses a running expedition. Reduced motion removes
camera follow/shake and shield flicker, reduces particles, and uses fading waves.

## Routes and hazards

| Route / sector | Quota | Clock | Feature |
| --- | --- | --- | --- |
| Survey / The Quiet Belt | 8 | 65s | Learn pickups, banking and dash attacks |
| Survey / Broken Relay | 10 | 65s | Telegraphing sentries |
| Survey / The Stormfront | 12 | 70s | Amber meteor warning lanes |
| Deep Orbit / The Shelf | 9 | 65s | The lip of the well |
| Deep Orbit / Foundry Spires | 10 | 70s | Five solid, indestructible refinery towers |
| Deep Orbit / The Well | 11 | 70s | Off-center gravity sink and meteors |
| Deep Orbit / The Leviathan | 12 | 80s | Three crackable vents and beam lanes |

Survey retains its original sector rules, controls, quotas and 2D default. Deep
Orbit unlocks for 250 Scrap or free on the first Survey victory.

Cores stay aboard until you spend **0.7 seconds** in the safe dock. Partial
deliveries are allowed. Cargo slightly reduces cruising speed. The navigation
chevron points toward a core or recommends heading home with a larger haul.
Rocks and sentries keep clear of the dock. Every sector transition repairs 1 hull.

Link pickups within **4.5 seconds** to grow the multiplier up to **x4**. Getting
hit or letting the chain expire resets it. Banked cores and carried cargo survive
hits. Dash immunity lasts 0.18s; pulse grants a 0.35s shield and stuns sentries
for four seconds.

Spires block the ship without damaging it and bounce rocks. They cannot be
broken by a dash. The well pulls the pilot and loose cores; touching its horizon
deals 1 damage and flings the ship out. Consumed cores respawn elsewhere. An ion
pulse reverses the pull for **1.5 seconds**.

The Leviathan slowly patrols the upper field. Dash into each glowing vent for
**400 points and 3 cores**. Hull contact hurts unless dashing; dashes bounce.
It sheds a core every 8s and warns an amber beam lane every 6s: **1.4s warning,
0.6s damaging beam**. Crack all three vents for **LEVIATHAN SILENCED**, 1500 points
and no more beams. Six cores begin in the field; banking the quota wins.

## Workshop, frames and draft

Every completed or failed run pays:

```text
Scrap = round((total banked × 8 + sectors cleared × 40 + (150 if won else 0))
              × route multiplier × broker multiplier)
Survey ×1.0; Deep Orbit ×1.25; Broker ×(1 + 0.15 per level)
```

A Survey victory pays 510 Scrap before Broker; an early loss with five banked
cores pays 40. Results show the payout, balance and progress toward the cheapest
locked item. Purchases appear as station modules in the live 3D Roost scene;
each unlocked schematic lights one fabricator indicator.

| Workshop item | Scrap | Permanent unlock / effect |
| --- | --- | --- |
| Deep Orbit Charts | 250 | Deep Orbit route; also free after first Survey victory |
| Kestrel / Albatross | 300 each | Ship frame |
| Chain Battery / Ballast Dampers | 120 each | Card schematic |
| Chronometer / Ram Plating | 150 each | Card schematic |
| Salvage Wing / Overdrive Core | 220 each | Card schematic |
| Hull Plating | 250 | +1 starting and maximum hull on every frame |
| Scrap Broker I / II | 180 / 300 | +15% / +30% payout; II requires I |
| Launch Rig | 350 | One seeded random unlocked card at level 1 on launch |

| Frame | Hull | Speed | Dash recharge | Magnet | Trait |
| --- | --- | --- | --- | --- | --- |
| Starling | 3 | 1.00 | 1.3s | 45px | Balanced |
| Kestrel | 2 | 1.15 | 1.0s | 45px | Smaller 11px hit radius |
| Albatross | 4 | 0.88 | 1.5s | 80px | Cargo slowdown halved |

Each sector dock offers **three distinct cards** from the unlocked pool, with a
maximum of **level 2**. Offers use an expedition RNG seeded at launch and include
an owned card below the cap whenever possible. These upgrades last for one run.

| Card | Tag / color | Benefit per level |
| --- | --- | --- |
| Tractor Array | SALVAGE / gold | +65px magnet |
| Twin Capacitors | MOBILITY / mint | −0.3s dash recharge, +8% speed |
| Reinforced Hull | SURVIVAL / coral | +1 max hull and repair |
| Ion Resonator | CONTROL / violet | +65px pulse radius, −1s recharge |
| Chain Battery | COMBO / gold | +1.5s chain; level 2 raises cap to x5 |
| Ballast Dampers | HAULING / seafoam | No cargo slowdown, −0.2s banking |
| Chronometer | TIME / blue | +8s on every later sector clock |
| Ram Plating | ASSAULT / coral | +0.1s dash immunity; dash-shatters add 1.5s clock |
| Salvage Wing | ESCORT / mint | One orbiting core-collecting companion |
| Overdrive Core | CONTROL / violet | Free pulse every sixth chain pickup; every fourth at level 2 |

## Scoring and saves

Core pickups pay 100 × multiplier, deliveries 50/core, rocks 75, sentries 150,
and deflected meteors 100. Sector landings pay 10 per whole second remaining +
150 per remaining hull point. Survey ranks: S 12,500 / A 9,500 / B 7,000.
Deep Orbit ranks: S 18,000 / A 14,000 / B 10,000. Lower scores rank C.

`user://starling.cfg` stores Scrap, Workshop ownership, route/frame selection,
per-route best score/rank/runs/victories, and sound/motion/Survey-view settings.
Legacy saves without expansion keys load with safe defaults and retain records.
`--unlock-all` uses `user://starling-preview-<process id>.cfg` and never writes
the real profile.

## 3D presentation and project layout

Simulation remains **2D Area2D actors in 1280 × 800 coordinates**. A separate
SubViewport mirrors actors onto a 3D XZ plane, with a tilted perspective camera,
subtle pilot follow, shadowed directional lighting, panorama sky and glow using
the **GL Compatibility** renderer. The field remains fully visible. GLBs bank,
bob, spin and tumble; the dock has a progress ring, and meteor/beam/sentry warnings
are drawn in world space. Effects, vent targets and navigation project through
the same camera. F3 only hides drawing; switching views never resets simulation.

| Path | Responsibility |
| --- | --- |
| `scenes/main.tscn` | Entry scene |
| `scripts/game.gd` | Coordinator, spawning, state transitions, payouts |
| `scripts/expedition.gd` | Pure route, draft, cargo, combo, clock and rank rules |
| `scripts/profile.gd` | Save compatibility, Workshop, frames and persistent records |
| `scripts/pilot.gd` | Movement, frame/card stats, abilities and damage |
| `scripts/core.gd`, `debris.gd`, `drone.gd` | Core and original hazard actors |
| `scripts/meteor_storm.gd` | Warned meteor lanes and deflection |
| `scripts/spire.gd`, `gravity_well.gd`, `leviathan.gd` | Deep Orbit mechanics |
| `scripts/salvage_wing.gd` | Orbiting companion collector |
| `scripts/presenter.gd` | 3D mirrors, camera, light, Roost and telegraphs |
| `scripts/model_assets.gd` | Optional GLB loading and primitive/existing-model fallback |
| `scripts/projection_overlay.gd` | Effects and UI markers projected into the 3D view |
| `scripts/arena.gd`, `effects.gd` | Original 2D field and bounded effects |
| `scripts/hud.gd`, `screens.gd`, `ui_style.gd` | Flight HUD, hub, dock draft, pause and results |
| `scripts/sound.gd` | Synthesized sounds, including vents, beams, inversion and purchases |
| `tests/smoke_test.gd`, `preview_flag.gd` | Input/physics integration and isolated CLI verification |

Artwork is bundled under `assets/art/`; models under `assets/models/`. The asset
helper checks `ResourceLoader.exists()` and falls back to an existing GLB or
primitive if expansion assets have not been imported. Child-node lookups tolerate
import suffixes. Automatic `.blend` import is disabled.
[Art notes](assets/ART_NOTES.md) describe the Blender construction and imagery.
The optional `tools/build_models.py` and `tools/build_deep_orbit_models.py`
regenerate the art; Blender is never needed to play.

## Verification

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd
# Same checks plus native screenshots:
godot --path . --script tests/smoke_test.gd
```

The suite uses real input events, overlaps and scene processing for the complete
Survey and Deep Orbit expeditions. It checks meta payouts/purchases/save migration,
the actual preview CLI flag in a child process, deterministic drafts, all frame
stats and card effects, spire separation/rock bounces, well pull/horizon/inversion/
core respawn, beam timing/damage, vents/SILENCED, model counts/positions, camera
bounds, F3 persistence and Roost modules. It uses temporary profiles throughout.

Native capture writes `/tmp/starling-v2-*.png`: Roost, Workshop, Survey 3D, each
Deep Orbit sector, Leviathan beam and silenced states, Scrap result, plus original
ability/dock/pause/victory/loss and smaller-window views.

For a manual native session with a separate profile:

```sh
godot --path . --maximized --script tools/native_playtest.gd
```

## Automated releases

The [Release macOS workflow](https://github.com/aranlucas/starling-orbital-salvage/actions/workflows/release.yml)
builds and publishes a universal macOS app when a version tag is pushed, or through
Actions → Release macOS → Run workflow. Version tags with a suffix such as
`v0.2.0-beta.1` produce prereleases. The workflow pins Godot 4.7.2, checks download
hashes, runs smoke tests, exports, verifies the universal binary/signature, and
launches the app from the release ZIP before attaching it and `SHA256SUMS.txt`.

To build locally with matching editor and export templates:

```sh
GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot \
  python3 tools/build_macos_release.py v0.2.0
```

Artifacts go to ignored `builds/release/`. The builder versions a temporary project
copy and leaves the source checkout unchanged.
