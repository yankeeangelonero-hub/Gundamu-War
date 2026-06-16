# Handoff — X-ray occlusion gating + Bayer dither, Director Grammar Phase 4 closeout, and the start of the fight event-log contract (resume 2026-06-17)

Picks up the long 2026-06-16 session (see the prior handoff,
`handoff-2026-06-16-director-grammar-continuity-and-xray-occlusion.md`). Three things shipped this
session and one thing is mid-brainstorm. Short version: the x-ray window now opens only when a mech is
actually occluded and reads as a clean Bayer screentone; the Director Grammar's Continuity dimension is
closed out (Phase 4, F34+F35); and we then stepped up a level and started spec'ing **what feeds the
director** — beginning with the fight event-log contract — but paused on the first open question.

## Where the build is
- **Branch:** `combat-feel-restart`, pushed to `origin` and in sync — HEAD = `e23e874`. This is the
  active combat-feel line; `main` still holds the archived backpack-editor experiment (do not use it).
- **Run it (the proven viewer):** `godot --path godot_director_spike -- --director=hybrid --log=fight_log_everything --armor`
  (windowed). Headless tests: `godot --headless --path godot_director_spike -s res://tests/<name>.gd`.
- **Godot 4.6.3**, GDScript + one spatial shader. `godot` on PATH (also `~/.local/bin/godot.cmd`).
- **GOTCHA — stale class cache:** a brand-new `class_name`/`.gdshader`/test file needs one
  `godot --headless --path godot_director_spike --import` pass before the engine registers it. The tell
  is "Could not resolve class X" / "Nonexistent function" / "script not found" — that is the stale
  cache, NOT a missing file. Run `--import` once, re-run. This bit us several times again this session.
- **GDScript gotcha:** `var x := actors["A"].position` fails to parse ("Cannot infer type") because
  dictionary access is untyped — use `var x: Vector3 = ...`. Cost us a parse error mid-session.

## The invariant that gates everything
The combat sim is pure/deterministic; the hybrid shot list is frozen by a golden hash. **Every
camera/render change must keep `tests/hybrid_check.gd` printing `got hash 2543717900`.** Every change
this session was presentation-only and held that hash. If it moves, something leaked into the
deterministic path — stop and find it.

## What shipped this session (all committed + pushed)
1. **X-ray occlusion now gated on real per-mech occlusion** (`46d47c2`). The shader was carving a
   window through any building along the camera→mech tube whether or not the mech was actually hidden.
   Now `director.gd._feed_xray_gate` runs the existing `Sightline.evaluate` per mech each frame and
   fades a per-mech enable (`xray_enable_a/b`, new global uniforms) up only when ≥3 of 5 silhouette rays
   are blocked (`XRAY_OCCLUDED_RAYS`), with a ~0.17s fade (`XRAY_FADE`) so it never pops. Tunable dials
   live in `director.gd` (the two consts) and `project.godot [shader_globals]` (`xray_radius=28`,
   `xray_softness=5`).
2. **X-ray see-through is a Bayer ordered dither** (`746c2c1`). Replaced the white-noise alpha-hash
   (which read as random stipple) with a 4x4 ordered/Bayer threshold in `xray_occluder.gdshader`, so the
   dissolve is a clean, regular halftone screentone. Still discard-based / order-independent — no
   transparency depth-sorting. Screen-locked pattern. The owner approved the look ("yup perfect" / "ok").
3. **Director Grammar Phase 4 — soft continuity closeout (F34 + F35)**, done via the full
   brainstorm → spec → plan → subagent-driven flow with two-stage review per task:
   - Spec `docs/superpowers/specs/2026-06-16-director-grammar-phase4-continuity-closeout-design.md`
     (`7e3683c`); plan `docs/superpowers/plans/2026-06-16-director-grammar-phase4-continuity-closeout.md`
     (`4c5900c`).
   - **F35 coherence guard** (`100dd24`): extracted the duplicated hero candidate-pose generation into a
     pure `director.gd._hero_candidates(...)` helper, and added `tests/coherence_check.gd` — a headless
     guard asserting every hero cut-in candidate AND the occlusion-picked pose stay on the keyed side of
     the A↔B axis across many geometries, both keyed sides, and several building layouts. Locks the 180°
     / screen-direction rule against silent regression. (`melee_cut` is intentionally excluded — it
     orbits the clash and may sit on either side.)
   - **Behavior-preserving dedup** (`df5e1b8`): `hero_os` and `hero_cut` now call `_hero_candidates`;
     hash held.
   - **F34** (`3086f07`): a comment formalizing the iso backbone as the establishing/re-establishing
     layout (already covered by `hybrid_check`'s three iso assertions). No behavior change.
   - **Final-review cleanup** (`4c2e3af`): dropped the now-dead `var d` local in both hero branches.
   - **UID sidecar** (`e23e874`): tracked `coherence_check.gd.uid` (repo convention — all tests/*.uid are
     tracked).
   - **F36 split_screen is deferred** (YAGNI). With this, the Director Grammar's seven dimensions are
     built out; only optional/parked items remain (split-screen, the angle-search iso fallback, a
     melee radius/height search, a distinct aftermath mood).

Full headless suite is green: `shot_grammar_check, grade_check, time_emphasis_check, continuity_check,
coherence_check, sightline_check, hybrid_check, director_check` (+ the variant blend/broadcast/iso/
witness checks). Note: `grade_check` prints some resource-leak ERRORs that are pre-existing and unrelated.

## The strategic turn (this is the new direction — read this)
After Phase 4 we zoomed out. The owner framed the grammar well: we turned a by-feel demo into a
**replicable cinematic conductor with tunable levers**. The next question the owner asked was "are we in
a good position to spec what *feeds* it, then work out the backpack system?" — and yes. The data chain is:

```
backpack build (grid · power · parts) → build stats + weapon mix
   → combat SIM (two builds + seed → deterministic event log)
      → FeelProfile (per-build lean: weight→cadence, weapon-mix→mode-mix)
         → Director Grammar  ← now built
```

Important reality check found by inspecting this branch: **only the playback half lives here.** The
director stages *static, hand-authored* logs (`godot_director_spike/data/fight_log_*.json`);
`fight_log.gd` is just a loader and `mech_actor.gd` is the actor it drives. There is **no live combat sim
and no FeelProfile on this branch** — the deterministic sim (M0) and the backpack build system (M1 grid +
power economy) were designed (specs exist: `docs/superpowers/specs/2026-06-14-backpack-engineering-
system-design.md`, `...m1-build-grid-and-power-economy-design.md`) and **built on `main`, then archived**
because that editor work broke combat feel.

Agreed sequence — work the seam **backward from the director** (matches the project's "opponents behind
one interface / sim and render separated / parts are data" architecture):
1. **Lock the fight event-log contract** (sim↔director interface). Highest confidence — fully derivable
   from the director we just built. ← we started this.
2. **FeelProfile** spec (per-build lean; its precondition "grammar designed first" is now met).
3. **Combat sim** — decide port the archived M0 vs. re-derive; it now has a frozen output (log) and
   input (build) to target.
4. **Backpack system** — graduate the existing backpack-engineering + M1 specs into plans, feeding the
   sim.
Carry one caveat the whole way: the backpack work was archived *for breaking combat feel*. The golden
hash and the pure-sim/render separation must be the explicit boundary when we reconnect the chain.

## In flight: the fight event-log contract brainstorm (resume here)
We invoked `superpowers:brainstorming` for the event-log contract and finished the context-gathering. The
contract is ~80% "write down and freeze what already exists." Key facts gathered:

- The existing logs already declare `schema: "km-director-spike-fight-log-v1"` and `tick_seconds: 0.1`
  at the root, with an `events[]` array. `fight_log.gd` already encodes a partial schema: required
  fields `["tick","actor","kind","payload"]`, the `KINDS` enum, `actor ∈ {A,B}`, events sorted by tick,
  root must have `events`.
- **Consumed-field inventory (the real contract surface), gathered by grepping director.gd / hybrid.gd /
  garnish.gd / grade.gd / spike_audio.gd:**
  - Every event: `tick` (int), `actor` ("A"|"B"), `kind` (enum), `payload` (dict).
  - `kind` enum: `spawn, advance, fire_beam, fire_burst, fire_missiles, fire_buster, melee, destroyed`.
  - `spawn`: `{x, z, hp}` (placement; consumed at scene/actor setup).
  - `advance`: `{to_x, to_y?(def 0), to_z?(def cur z), end_tick, boost?(def false)}`.
  - `fire_beam`: `{hit?, blocked?, damage, lethal?, hp_after?}`. director reads hit/blocked/damage/
    lethal; hybrid build_shot_list keys the kill-cam off `lethal` and the over-shoulder off the first
    beam; grade maps `lethal`→"death" mood.
  - `fire_burst`: `{rounds, hits, damage?, hp_after?}`. director reads hits; garnish reads rounds/hits;
    spike_audio reads rounds.
  - `fire_missiles`: `{count, hits, damage, hp_after?}`. director reads hits; garnish reads count/hits.
  - `fire_buster`: `{hit, damage, lethal?, overkill?, hp_after?}`. garnish sets `_last_kill_class` from
    `lethal`; director reads hit/damage.
  - `melee`: `{style?(def "cleave"), result?(def "lock"; "knockback"|"lock"), hit?, blocked?, lethal?,
    damage?}`. (Not present in fight_log_everything, but director dispatches it; there are melee logs.)
  - `destroyed`: `{}` (empty).
  - **Informational-but-unread-by-director:** `hp_after`, `overkill` — carried in logs, never read by
    the director (HUD/debug/FeelProfile fodder). A contract decision: required-but-ignored vs optional.

Two non-trivial findings beyond "freeze it":
- **Weapon identity currently lives entirely in the `kind` enum.** `shot_grammar.gd.yield_tier(kind)`
  maps the kind *string* → spectacle tier (capital `fire_buster`=3, sidearm=1) and drives the staggered
  kill blast. So `kind` is the weapon-CLASS channel. When the backpack produces arbitrary weapons,
  something must decide which class/tier each maps to — this is the load-bearing fork for how the
  backpack connects to the contract.
- Positions are event-driven (spawn + advance interpolation), NOT a per-tick position stream — keep it
  that way; the sim is the source of truth and emits beats, not frames.

**THE OPEN QUESTION we paused on (answer this first when resuming).** How should a weapon's identity /
spectacle class be carried, once the backpack produces arbitrary weapons? Three options were on the table
and the owner asked to *clarify before choosing* (they want to talk it through, not pick blind):
  a. **Fixed class enum via `kind`** — keep `kind` as a small fixed weapon-CLASS vocabulary; every
     backpack weapon maps to one class at sim time; director untouched. Simple, but the backpack can
     never stage a weapon outside the existing vocabulary.
  b. **Explicit `weapon_class` + `yield_tier` payload field** — the sim states the spectacle directly,
     `kind` can go coarse; more flexible for novel weapons, but the director changes to read the field
     and the kind→tier map moves into the sim/contract.
  c. **Decide later** — freeze the rest of the contract now at the kind-based model and defer the
     weapon-identity question to the combat-sim/backpack spec as a known open seam.
  The owner's likely real question behind this: do they yet have a mental model of how a backpack weapon
  becomes "a shot," and is weapon *visual variety* even a v0.1 goal? Resolve that with them, then pick.

Other contract decisions still to make once the weapon channel is settled (none blocking yet):
- **Determinism / PvP header:** should the contract reserve header fields for the seed + build identity
  (so a headless re-sim can verify a stored result — the war-endgame enabler in CLAUDE.md), or keep the
  header minimal now? Lean toward reserving, because the architecture "must not preclude" the war
  backend, but it is a real call.
- **Informational fields** (`hp_after`, `overkill`): part of the contract the sim must emit, or
  optional/consumer-ignored? They are useful to the HUD and the FeelProfile.
- **Schema version string + validation:** formalize `km-director-spike-fight-log-v1` and where it is
  asserted (extend `fight_log.gd`?).
- **Boundary clarity:** the FeelProfile is per-BUILD and is NOT part of the per-FIGHT event log — keep
  them separate (different specs). The contract spec should say so explicitly so the seam is clean.

## How to resume
1. Re-enter the event-log contract brainstorm. Start by clarifying the weapon-identity question WITH the
   owner (see "THE OPEN QUESTION"), then settle the other contract decisions above, then write the spec
   to `docs/superpowers/specs/2026-06-17-fight-event-log-contract-design.md` and proceed to a plan.
2. After the contract: the FeelProfile spec, then the combat-sim decision (port M0 vs re-derive), then
   graduate the backpack specs into plans.
3. The viewer may still be running from tonight (a `Godot_v4.6.3-stable_win64` process). Kill stray
   processes before relaunching: `Get-Process | ? { $_.ProcessName -match 'Godot' } | Stop-Process -Force`.

## Files map (new/changed this session, under `godot_director_spike/`)
- `scripts/shaders/xray_occluder.gdshader` — per-mech enable gate (`xray_enable_a/b`) + Bayer dither.
- `scripts/director.gd` — `_feed_xray_gate` + `XRAY_FADE`/`XRAY_OCCLUDED_RAYS` consts; new
  `_hero_candidates` static helper; dead `d` removed from the (caller) hybrid branches.
- `scripts/directors/hybrid.gd` — hero_os/hero_cut call `_hero_candidates`; F34 establishing comment.
- `project.godot [shader_globals]` — `xray_enable_a/b` declared (defaults 0).
- `tests/coherence_check.gd` (+ `.uid`) — the new F35 continuity guard.
- Specs/plans under `docs/superpowers/` as listed above.
