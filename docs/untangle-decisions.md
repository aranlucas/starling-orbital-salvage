# Untangle decision log — 2026-11-06

## Scope and baseline (before implementation)

Whole-repository inventory: Godot runtime (`scripts/`, both Survey and true 3D
Deep Orbit), integration suites (`tests/`), release/install and optional Blender
authoring tools (`tools/`), scenes, export settings, assets and design documents.
HEAD b7a8597; working tree clean; no applicable AGENTS.md found. Preserve the
established two gameplay modes, balance, save migration, optional art fallback,
and historical design documents. Both Comments and Tests additions selected.
No local tests, builds, benchmarks or browser tests will run. No owned test
process was present. Baseline behavior is not locally verified. CI must distinguish
baseline failures from introduced failures using the base revision if necessary.

## Design and inventory

1. Put Survey geometry in a stable SurveySpace definition, consumed by simulation
   and presentation.
   - Hidden links: dock center repeated in game, arena, debris, drone, presenter,
     projection overlay; docking radius repeated in rendering and delivery.
   - Preserve distinct pilot/rock bounds and hazard clearance: these are balance
     requirements, not interchangeable copies of one radius.
2. Put shared ship build rules in ShipBuild, preserving dimension-specific ranges.
   - Hidden links: hull capacity duplicated in mission launch, jump repair and both
     pilots; speed, recharge, drag and pulse cooldown repeated between pilots.
   - Keep 2D/3D movement and dimension-specific magnet/pulse/dash-duration tuning
     separate; no general actor inheritance or workflow framework is warranted.
3. Declare Deep Orbit features and initial loose core count in sector definitions.
   - Hidden positional convention: coordinator identifies spires/well/boss and
     boss core count using sector indices 1/2/3. Sector ordering should not define
     a feature's identity.
4. Share a strict CI gameplay runner between PR and release validation.
   - Missing link: release-only workflow runs Survey but never the 3D suite;
     there is no pull-request behavioral gate.
   - Godot can log script errors without a nonzero exit: reject error output as
     well as process failure. Keep installation/release checksum verification.
   - Native integration currently mandates a 60fps benchmark on arbitrary hardware;
     make it explicit opt-in so functional failures indicate gameplay regressions.
5. Include runtime GLBs in exports while excluding Blender source files.
   - Export excludes all models, silently replacing shipped 3D art with primitives.
     Standalone menu startup does not prove runtime models are packaged.
6. Remove implementation-restating comments and shallow signal wrapper; preserve
   engine/platform explanations, legacy save requirements, and art provenance.
   - Existing tests mostly exercise real input, overlaps, persistence, scoring,
     progression and assets. Preserve them; do not delete internals-assisted setup
     just because integration fixtures need controlled actors.

## Retained special cases and boundaries

Optional art fallback and imported-node suffix handling support missing imports.
Mouse capture headless intent checks reflect dummy display limitations. Preview
save isolation and legacy Survey victory migration are compatibility requirements.
Bounded spawn attempts and marker placement avoid unbounded frame work. Boss
vents, well respawn and safe dock exclusion are distinct gameplay requirements.
Original/expansion Blender generators contain shared geometry helpers; review for
safe extraction without conflating their distinct bevel/render/export settings.

## Validation and reviews

Initial independent repository review in progress; findings will be retained here.

Initial independent review confirmed items 1–6 and added:
- Headless scanner contacts/offscreen helpers duplicated actual draw predicates.
  Actual drawing now consumes the same contact entries and offscreen predicate.
- Dead static menu artwork node and unused Blender Vector import removed; source
  artwork retained. Existing asset generators intentionally keep different bevel
  and scene setup defaults; no shared authoring framework introduced.

Implementation: shared geometry/build definitions, explicit sector feature metadata,
GLB export inclusion, shared strict gameplay runner and PR workflow implemented.
Native frame budget remains available through explicit `-- --benchmark` only.
PR CI diagnoses baseline with the same runner after a head failure, without masking
that failure. No local tests or builds were run.

Final independent review: no actionable regressions or worthwhile remaining
structural issues. Shared stats preserve legal build behavior and each mode's
units; geometry and sector metadata are consistent; scanner rendering consumes
tested entries. Meaningful input/overlap/progression/persistence tests retained.
Static whitespace check passed. Behavioral verdict awaits PR CI.
