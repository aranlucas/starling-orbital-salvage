# Deep Orbit free flight — design (Phase 1.5)

Supersedes the "simulation stays 2D, 3D is a presenter" decision **for the Deep Orbit
route only**. Everything else in `2026-10-31-starling-deep-orbit-design.md` still stands.

## Why
Phase 1 drew the flat 2D game with 3D models. The user wants to be **in** 3D space:
fly a ship through a volume, with cores above and below you and a station to fly home to.
They chose **chase-camera free flight**, with **Deep Orbit rebuilt as true 3D**. The
original Survey route stays as the classic 2D mode, including its F3 presenter view.
The Roost, Scrap, Workshop, card draft and frames are shared by both routes.

## Goals
- Deep Orbit is a real 3D game: Node3D/Area3D actors in a 3D volume, a chase camera behind the ship, and free pitch and yaw.
- It keeps the rules unchanged: quota, clock, chain multiplier, bank at the dock,
  dash shatter, ion pulse, sector docks with the card draft, and the same Scrap payout.
- **Readability in 3D is the top risk** and is a first-class feature: off-screen indicators,
  a height-aware radar, telegraphs drawn as volumetric shapes, and a damage-direction cue.

## Anti-goals
- Disorientation. There is no full 6DOF tumbling. The world has an "up" (the Roost's plane).
  The ship banks visually but auto-levels, and pitch is clamped to ±75°.
- Hazards that kill you from behind with no warning.
- Requiring a mouse. Keyboard-only play must be fully viable.
- Breaking the Survey route, its tests, or saves.

## Flight model (*agent's call*, tune by feel)
| Input | Action |
| --- | --- |
| Mouse (captured while flying) **or** arrow keys | Steer the nose (yaw and pitch). Steering is rate-based and smoothed. |
| W / S | Thrust / brake (S to a near-stop, then slow reverse) |
| A / D | Strafe left / right |
| Space | Dash: a burst in the current travel direction (or the nose if stopped). Grants immunity and shatters. |
| E | Ion pulse: a sphere. Scatters rocks, stuns sentries, pulls cores, inverts the well. |
| I | Toggle invert-Y (saved) |
| Esc / P | Pause, which releases the mouse |

- Cruise is ~38 m/s, the dash ~110 m/s for 0.25 s, and the ship is ~4 m long. Acceleration
  is snappy and arcade-like, with light inertia. Cargo slowdown and frame stats carry over.
- Camera: a spring-arm chase cam behind and slightly above the ship that lags a little on turns.
  FOV widens with speed and on dash. Reduced motion disables FOV kicks, shake and camera lag.
- The mouse is captured only during active flight. It is released on pause, menus, docks, results and focus loss.

## The volume
- Each sector is a sphere of radius ~200 m centered on the **dock at the origin**.
- **Dock:** `dock_beacon.glb` at the origin, scaled large and ringed. Banking works as in 2D:
  hold within ~10 m of the center for 0.7 s (faster with Ballast Dampers).
- Past ~185 m a "LEAVING SALVAGE ZONE" warning shows, and a soft force steers you back.
- Cores spawn in a shell 60–180 m from the dock at varied heights (±70 m).
  Rocks drift and tumble in 3D and bounce off the boundary.
- Set dressing gives a sense of place and speed: the **Roost station** visible in the distance,
  wreck fragments, a broken orbital ring arc, and fine space dust/streak particles near the camera.

## 3D readability kit (required)
- **Radar:** a bottom-center elliptical scanner in the style of a space-sim scanner. Blips sit on the
  ship's horizontal plane, with a stalk up or down showing relative height. Colors: cores gold,
  dock mint, rocks grey, sentries red, the Leviathan large and red, the well violet.
- **Screen-edge indicators:** for the nearest cores (up to 3), the dock (always, labelled with
  distance in metres), and any hazard currently telegraphing at you.
- **Waypoint marker** on the navigation target, replacing the 2D chevron.
- **Telegraphs as 3D shapes:** sentry lunge lines as laser lines to your position, meteor lanes and
  Leviathan beams as translucent amber cylinders that solidify on fire, and a warning ring
  on the screen edge when the threat is behind you.
- **Damage-direction flash** at the screen edge.
- A target bracket around the core you're closest to collecting.

## Mechanics in 3D
| Sector | Notes |
| --- | --- |
| THE SHELF | Intro sector. The broken ring arc and wreck fragments frame the volume. 1 sentry. |
| FOUNDRY SPIRES | 5 giant spires (~150 m tall, ~12 m wide) cross the volume vertically. You slide along them without damage. |
| THE WELL | A sphere sink ~80 m from the dock. Pull falls off by radius ~110 m, and the horizon is r ~12 m (damage and fling). Pulse inverts it for 1.5 s. Meteor lanes cross near the player. |
| THE LEVIATHAN | The hulk is scaled to ~90 m and patrols a loop around the dock. It has 3 vents on its top hull; dash into a vent to crack it (+400 and 3 cores spill out). Hull contact damages you unless you're dashing (a dash bounces). Every ~6 s it fires a beam (1.4 s warning, then 0.6 s firing). SILENCED after 3 vents. |

The scoring, quotas, clocks, ranks, draft, frames, cards (with ranges converted
to metres) and Scrap from the Phase 1 tables all still apply. The Salvage Wing orbits the ship in 3D.

## Assets
Existing GLBs are reused. Codex Terra adds or updates:
- `deep_orbit_sky.png` v2: a full equirect sky that looks good in every direction,
  with a shaded gas giant and an atmospheric rim (not a flat disc).
- `leviathan.glb` v2: detailed enough for close passes (≤ 60k tris), with the same `Vent_0..2` names.
- `wreck_fragments.glb` (children `Fragment_0..5`) and `ring_arc.glb` (a broken orbital ring segment).

## Testing
Use real input events (keys and mouse motion) and physics overlaps in 3D:
- Flight: steering, thrust and strafe, pitch clamp, auto-level, the boundary push and warning.
- Core pickup, chains, banking at the dock, and dash shatter.
- Pulse effects, sentry telegraph/lunge/stun, spire slide, well pull/horizon/inversion.
- A full Leviathan fight: vents, beams, SILENCED, victory and Scrap payout.
- Radar blip count, plus indicators for off-screen targets.
- Mouse capture and release on pause and results, and keyboard-only steering.
- The Survey route suite stays green.
- Non-headless screenshots: each sector from the chase cam, a dash, a Leviathan close pass, a beam warning from behind, and the radar.
