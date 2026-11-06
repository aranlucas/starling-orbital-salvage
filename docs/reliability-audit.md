# Correctness and reliability audit — 2026-11-06

## Baseline and inventory (recorded before implementation)

Remote default and clean bound worktree: `738f4f0a6fdf1621f31a25a8e673e345b781cb33`
(merged untangle pass). No applicable AGENTS.md. This pass preserves public APIs,
balance, both routes, existing tests and structural decisions.

- Runtime: GDScript scenes, shared Expedition rules, Survey Area2D actors and
  Deep Orbit CharacterBody3D/Area3D actors. Inputs lead through launch, pickup,
  banking, sector draft, victory/loss, payout, Workshop and replay.
- Persistence/trust boundary: local ConfigFile at user://starling.cfg contains
  records, currencies, ownership and settings. Preview uses a process-specific
  separate path. No network, accounts, tenant boundary or external credentials.
- Presentation: HUD/screens, 2D-to-3D presenter, scanner, optional model fallback,
  audio and effects; pause disables world processing and releases mouse capture.
- Tooling: Python Godot installer/check runner/macOS exporter and optional Blender
  asset authors; PR gameplay CI and tag/manual release CI. No JS/TS or package
  manifests: tester-army/e2e web/mobile engines have no applicable target here.
  Keep the native Godot input/physics/persistence journeys rather than invent a UI.
- Review covers success/failure paths for transitions, payout idempotency,
  deferred actors, core collection/respawn, draft caps, timers, bounds, save
  migration, preview isolation, process timeouts and release integrity.

## Findings

### F1 — malformed but parseable saves break loading or record consumers (medium, high confidence)

`scripts/profile.gd:load_profile` trusts ConfigFile Variant types for `owned`,
`routes` and nested route records. For example `[mission] routes={"survey": {}}`
loads successfully but HUD reads `.best` and Records reads missing fields;
`routes="damaged"` cannot be assigned to Dictionary; `owned=42` is not iterable.
Scalar `best=[]` also cannot be converted to int. A manually edited or partially
schema-damaged save can therefore interrupt startup or the first payout. Expected:
retain valid fields, recover invalid fields to legacy/default values, and keep
both records screens and later payouts usable. Normalize at the load boundary;
retain legacy migration and valid saved data. Add isolated ConfigFile regressions.

## Rejected hypotheses and limits

- Repeat result payout: `_finish` accepts only running/paused and changes state
  before recording; a repeated finish cannot award twice.
- Double pickups: both core types set `taken` before emitting; the well checks
  taken before consuming. Pausing disables world processing.
- Upgrade injection: `advance` verifies offered ID, quota and route end; offers
  exclude capped cards and return copies.
- Survey presenter stale pilot on Deep Orbit: camera follows only a valid pilot;
  hidden viewport is disabled. This alone is not evidence of a defect.
- No external authentication, retries, multi-tenant transactions or production
  services exist. Local profile writes currently warn on failure; atomic recovery
  would be a separate behavioral change, not claimed fixed by normalization.

## Validation plan

No local tests, builds or benchmarks. Preserve both existing suites; add a CI-only
profile regression script and run it on the base code to require a genuine pre-fix
failure, then on the fixed code. PR CI should also exercise the existing universal
macOS export/standalone verifier and retain diagnostic output. Independent static
review challenges the findings and final implementation. CI outcomes recorded below.

## Review and baseline CI evidence

Independent static reviewer confirmed F1 and found no additional high-confidence
runtime defect. Its objection to an unbounded pre-fix process was addressed with
a 30-second subprocess limit plus mandatory `SCRIPT ERROR`/`profile.gd` evidence;
a timeout alone cannot pass the reproduction gate.

Remote main CI run [42287317659](https://github.com/aranlucas/starling-orbital-salvage/actions/runs/42287317659)
already failed the Survey Ballast check (94/95 checks), while pre-merge PR run
42287048642 passed. Investigating fixture contamination before altering assertions.

### F2 — Ballast integration fixture permits unrelated pickups (CI reliability)

`tests/smoke_test.gd:_test_card_actors` activates Overdrive's 0.8s core attraction,
then teleports to dock and assigns cargo=2 while remaining cores still simulate.
Random starting positions permit those cores to arrive during the banking wait,
invalidating the exact cargo/banked expectation. Independent review confirmed
this path. Isolate the final banking fixture by removing loose cores, resetting
motion/progress and asserting no early bank followed by exactly two delivered
cores. Keep real process-driven docking and exact assertions. CI must validate.
