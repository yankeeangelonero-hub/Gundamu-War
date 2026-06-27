# Handoff — three archetypes locked; M1 grid-editor design under review

Date: 2026-06-28 (very late night session, ran past midnight)
Branch: `combat-feel-restart`
Repo: `D:/claude/Gundamu-War`
State: working tree clean, all committed, roadmap canon synced to HEAD.

This is a resume handoff. The session did two large things: it shipped the fireworks
spectacle ruler in the morning, then spent the rest of the night turning the loadout
showcases into three owner-approved archetypes with full weapon/feel spectacle. It ended
right as we started reviewing the M1 build-grid design — that review is where to resume.

## What landed this session (all committed on combat-feel-restart)

The fireworks ruler (cf-fireworks, shipped). `scripts/sim/spectacle_report.gd` aggregates
the whole kit x opponent matrix against the fight_log_everything baseline; `main.gd
--spectacle-report` emits a candidate-vs-baseline artifact (text + tmp/spectacle_report.json)
with per-cell dead-air / density / weapon-mix / finisher pass-fail. Deterministic; tests
spectacle_report_check + spectacle_report_matrix_check. The roadmap node is marked shipped.

A choreographer fix that matters broadly: standoff engages are now centre-anchored
(band/2 from the fixed centre on each mech's own side) instead of measured off the enemy's
transient mid-dash position. That killed an opening contact-collapse and a slow positional
drift, and it is the lever every "hold range vs charge in" decision now rides on. New
per-preset overrides were added in `_engage`: `BTRADE_BAND` (fix the beam-trade standoff
distance independent of heft) — this exists because weapon `mode_weights` gate which exchange
a weapon can do, so a preset's `mode_mix` alone cannot force a suit to hold range or close.

Three archetypes are tuned, owner-approved, and saved (memory: weapon-spectacle-direction).
They are mockups built bespoke-first; the plan is to consolidate the weapon VFX into a
data-driven vocabulary later, and to "resolve" how the archetypes are bundled later. Launch
any of them with, from the repo root:

    $godot = 'C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe'
    & $godot --path godot_director_spike -- --director=hybrid --build-ui --auto-fight --showcase=<name> --armor

- `--showcase=rifle` — Fast Gunner Ace. `rifle_missile_showcase` kit + `bombard` preset.
  Varied powered-up arsenal (beam / missiles / plasma / railgun) plus a signature Full Burst
  (fire_full_burst: a planted alpha-strike firing railgun lines from 4 shoulder mounts +
  plasma bolts from 4 waist mounts + the main beam at once — body mounts on
  MechActor.railgun_mounts()/plasma_mounts()). Tripled fire rate. Holds range (BTRADE_BAND 70).
  Fast/agile (heft 0.2 -> ~192 speed cap). Dodges ~half the incoming fire (evasion 0.4).
- `--showcase=gerobi` — Siege Buster Rifle. `buster_rifle_showcase` kit + `siege` preset.
  Slow heavy suit (heft 0.85) that plants (clash_lock while firing) and unleashes a SUSTAINED
  massive ~7-wide beam (fire_gerobi) held ~1s that vaporises a wide swath of city. No dodge,
  far standoff (BTRADE_BAND 82).
- `--showcase=saber` — Duelist (melee). `saber_booster_showcase` kit + `duelist` preset, foil
  `duelist_ghost`. Tight circles (ORBIT_AMP 0.2), sticks close, saber-dominant. Melee is staged
  as SUIT-AS-PROJECTILE: the lunge boosts all the way to the impact tick into true contact
  (twin_sabers travel 7); a connecting blow yanks the struck mech into contact (co-location in
  the choreographer's melee reaction) and a miss dodges clear. Each strike erupts a flurry of
  giant beam-sabers from the hand (parented to the muzzle so they track the body). Melee cameras
  were pulled back (cut 38 / chase 30 / profile 44 / high 48, radius_factor 1.7) to stop
  occlusion.

New weapon viewer-kinds added this session (all bespoke VFX in garnish.gd, wired through the
two dispatch matches in garnish + director.gd, the ShotGrammar yield table, and the
DEBUG_*_TO_KIND maps in main.gd): fire_plasma, fire_railgun, fire_full_burst, fire_gerobi.
New presets in data/grammar_presets.json: bombard, siege, duelist. New per-suit `evasion` stat
threaded into the generator's _roll_hit (fast suits dodge ~evasion of shots; a miss is already
tagged evade, the choreographer weaves the suit, the beam overshoots into the buildings behind).
Opponents can override their kit's stance via per-opponent grammar_preset + evasion fields.

Known melee limit (recorded): contact-at-the-exact-impact-tick is NOT guaranteed against a
FLEEING foil — the enemy moves between cue and strike, so the lunge targets a stale position.
Mitigated by pairing the saber against a melee foil (both converge) plus the giant blades
bridging the residual gap. The real fix, if ever needed, is a TWO-PASS staging that anticipates
the enemy's strike-tick position. This is the seam the positionless-deterministic-sim /
choreographer-stages-positions split stresses hardest.

Tests: full grammar + sim suite green (mirror-equivariance grammar_blind_check, range gates
grammar_stage_check, determinism loadout_generator_check, showcase_distinct_check,
choreo_range_floor_check, shot_grammar_check). NOTE: the headless `--script` test runs were
SLOW this session (sometimes 30-60s each, occasional 2-min timeouts when batched) — run them
singly with generous timeouts.

## Two owner decisions made

1. The starting roster is THESE THREE archetypes (gunner / siege / duelist). The buster
   showcase and any others come later. The buster showcase (--showcase=buster) has NOT had the
   spectacle/feel pass and is still the earlier baseline.
2. The next build is the M1 backpack grid editor (the "arrange the backpack" half of the
   vision), NOT the pick-a-matchup sandbox. The grid is standalone-testable and parallel to the
   sandbox route.

## Where to resume: the M1 design review (NOT yet building)

The M1 spec is `docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`
(written 2026-06-14 on the archived build-editor branch, BEFORE the combat-feel/archetype work,
so it deserves a fresh read). No M1 grid code survives on this branch — building fresh.

A pure-core implementation plan was already written:
`docs/superpowers/plans/2026-06-28-m1-build-core-grid-resolver.md` — BuildGrid (pure 5x4 grid
geometry + validity) + BuildResolver (pure PoE increased/more economy) + item palette + TDD
tests. It is NOT executed. It is correct for the spec as written, but the grid size and a few
scope questions are under review (below), so do not run it until those settle — at minimum the
GRID_W/GRID_H constants will change.

We had just started a design review and surfaced three open questions; these are the resume
agenda:

1. GRID SIZE / what the grid represents. 5x4 (20 cells) is too cramped for a maxed feared ace.
   The owner floated 36x36 (~1300 cells) but on reflection felt that is too much (even a maxed
   build fills under 10% of it — a sprawling mostly-empty canvas, a totally different feel from
   the tight 5x4 puzzle). UNRESOLVED. The framing to resume with: is the grid (a) a high-res
   mech-BODY assembly you fill densely with small components, (b) a vast canvas you start in a
   corner of and grow into over the game, or (c) just "more room than 5x4" — in which case a
   denser mid-size grid (~12x12 with bigger items) likely serves better than 36x36. Settle this
   first; it drives the grid size AND the item scale.

2. TRANSFORMS scope — the spec and the roadmap disagree. The spec says M1 supports carry VALUE
   MODIFIERS ONLY (added/increased/more) and defers fork/chain/multishot TRANSFORMS to M2. The
   roadmap node m1-grid-editor's goal says M1 supports buff AND author adjacency transforms
   (fork/chain/multishot). Decide whether M1 is just the number economy or also behaviour
   transforms.

3. How a grid build connects to the archetype FEEL we just built. The spec predates the
   archetypes. Today gunner/siege/duelist are hand-tuned presets (stance, speed, evasion). A grid
   build produces weapons + power stats but not that feel. The intended bridge is FeelProfile
   (cf-feel-core: derive(build) -> {heft, tempo, mode_mix}), so a heavy grid build BECOMES the
   siege feel automatically. Decide whether the grid drives the archetype feel or feel is a
   separate choice on top. Also relevant: docs/superpowers/specs/2026-06-26-m0-m1-game-system-bridge-design.md
   (the M0/M1 loadout-to-fight bridge draft, still a `decision` node dec-m0-m1-bridge).

Suggested resume order: settle (1) grid size + intent, then (2) transforms scope, then (3) the
feel bridge; revise the M1 spec to match (and reconcile the roadmap node's transforms line);
then update/execute the pure-core plan with the agreed grid constants.

## Roadmap / board

roadmap.json is synced to HEAD. cf-fireworks is shipped. m1-grid-editor is `ready` (its spec is
the one under review). The 3-archetype work is the eye-validation of m0-sandbox-sim's "archetypes
read distinctly" requirement (still in-progress; not flipped). team-battle remains a parked
`pending` node. The path after M1: build-picker -> cf-sandbox (first playable), then graft M1.

## Key files touched this session

- godot_director_spike/scripts/garnish.gd — all new weapon VFX (_plasma/_railgun/_full_burst/
  _gerobi + swath, _saber_flurry hand-rooted, _draw_gerobi sustained beam).
- godot_director_spike/scripts/sim/choreographer.gd — centre-anchor standoff, BTRADE_BAND
  override, melee suit-as-projectile engage + co-location reaction.
- godot_director_spike/scripts/sim/loadout_fight_generator.gd — evasion in _roll_hit, per-opponent
  grammar_preset/evasion overrides, resolve_showcase.
- godot_director_spike/scripts/director.gd, director/shot_grammar.gd — dispatch + yield + melee
  camera framing + 3x feel speed curve.
- godot_director_spike/scripts/mech_actor.gd — railgun_mounts()/plasma_mounts(), full-armor accel.
- godot_director_spike/data/{m0_loadout_kits.json, grammar_presets.json} — showcase kits,
  showcases map, presets, evasion, foils.
- docs/superpowers/specs/2026-06-27-archetype-showcase-fights-design.md (the archetype spec),
  docs/superpowers/plans/2026-06-28-m1-build-core-grid-resolver.md (the M1 pure-core plan).
- memory: weapon-spectacle-direction.md (the saved archetypes + melee limit).
