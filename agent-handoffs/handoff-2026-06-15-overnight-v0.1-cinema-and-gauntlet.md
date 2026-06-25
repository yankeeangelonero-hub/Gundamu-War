# Handoff — overnight v0.1: enriched UC cinema + the full backpack gauntlet

This picks up directly from `handoff-2026-06-15-m0-fight-and-camera-movement-gap.md`. That handoff
diagnosed two gaps: the deployed M0 fight read thinner than the hand-authored combat reference
(because the sim emitted a sparse stand-and-shoot log), and the backpack existed only as an M1 build
editor with no game loop around it. Both are now closed. This was built overnight in orchestrator
mode — Sonnet agents implemented each slice, every slice was independently verified (tests re-run,
diffs scoped, frames inspected) before the next was dispatched.

All work is on `main`'s working tree, **uncommitted**, ready for your review and commit.

## What landed

**Enriched cinematic combat (the camera/movement gap).** Worked in the leverage order the prior
handoff prescribed — movement first, then camera, against the 2026-06-13 Gundam-UC combat-feel
research. All of it is deterministic data on the existing log → director → garnish pipeline; the
fight outcome is still a pure function of the stats (verified by an outcome-invariance test).

- `scripts/build/build_fight_sim.gd` now emits a rich log instead of two cosmetic advances: grounded
  burst-coast-snap repositioning with `to_y` pop-up hops (your "grounded with bursts" choice — not a
  full airborne dogfight), all-range `fire_swarm` volleys (replacing `fire_missiles`, build-driven
  off the missile fx), `evade`/`pursue` dodge-pursuit runs, a pressure→reversal→climax pacing arc,
  and a `hero_kill` flag on the killing blow. **No melee this pass**, per your call. The event
  contract (`data/event-contract.md`) documents every new kind/field.
- `scripts/mech_actor.gd` + `scripts/garnish.gd` dramatize them: thrust profile with boost flares,
  pop-up hops with landing dust, tightened AMBAC arm/leg snap on hard pivots, Itano-circus swarm
  fan-out, evade/pursue motion, and a capital-grade `hero_kill` treatment (oversized beam, whiteout
  sphere, screen-fill, extra collateral). Movement dials were retuned off the block-out placeholders
  (`max_speed` 48→52, `max_accel` 24→18, boost impulse 21→26, etc.) — **these want your eye; they're
  defensible starting values, not final.**
- `scripts/directors/hybrid.gd` broadens the camera grammar: the core fix is that it only intercut on
  `fire_beam` before (so gatling/swarm/buster fights got no hero cuts) — it now intercuts on any fire
  kind, adds an overload build-up beat, a low/heroic `popup_burst` shot, a wide `chase_pursuit`
  tracking shot, and an escalated bullet-time on `hero_kill`. UC grammar (F4–F6) per your camera
  reference, iso backbone preserved.

**The full backpack gauntlet (was: M1 editor only).** Built per
`docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md` §"v0.1 traditional
gauntlet", wrapping the existing build screen / resolver / mounts / fight rather than forking them.

- `scripts/gauntlet/` (run_state, shop_state, gauntlet_screen) + `scenes/gauntlet_screen.tscn` +
  `data/pilot_defs.json`. Pick a pilot (e.g. VESPER-7, who brings a signature item), then a round
  loop: shop phase (buy / sell / reroll, all gold-gated and run-seeded) → ENTER BUILD & DEPLOY →
  watch the enriched cinematic fight vs a ghost → win earns gold + advances, loss costs a heart →
  until hearts hit zero or the win round. Bag-expansion is real container items that grant cells
  (`build_grid.gd`, `build_items.json`).
- **Deferred, cleanly stubbed:** recipes/merging is a documented data hook (`recipes: []` + the lock
  infrastructure) — not half-wired. This is the obvious next economy slice.

## How to see it

- The loop: run the gauntlet scene, pick a pilot, shop, build, deploy, watch, repeat.
  `godot --path godot_director_spike res://scenes/gauntlet_screen.tscn`
- The cinema, at a glance: `godot_director_spike/tmp/enriched_fight_contact.png` (contact sheet of a
  full 24s enriched fight), `enriched_fight_hybrid.mp4` (the movie), `enriched_hero_kill_money.png`
  (the kill money shot), `shop_screen.png` (the gauntlet shop UI).

## Verification

The full combined suite is green on `main` — 15 `*_check.gd` files, run headless via
`godot --headless --path godot_director_spike -s res://tests/<name>.gd`:

- Cinema: `build_fight_sim_check` (determinism + outcome-invariance + every new beat), `hybrid_check`
  (broadened cuts + escalated hero-kill), `director_check`, `iso_check`, `blend_check`,
  `witness_check`, `broadcast_check`.
- Backpack: `build_resolver_check`, `build_grid_check`, `build_mounts_check`, `build_screen_check`.
- Gauntlet: `gauntlet_economy_check`, `gauntlet_run_loop_check`, `gauntlet_round_smoke_check`,
  `gauntlet_bag_expansion_check`.

Determinism held throughout (same build + seed ⇒ byte-identical log), so the PvP re-sim premise
survives. IP rules held (mono-eye / single visor identity; UC named units used only as feel targets).

## Follow-ups for you

1. **Tune the movement dials by eye** — the retuned values are starting points; watch a deployed
   fight beside `--log=fight_log_everything --director=hybrid` and adjust weight/burst cadence.
2. **Recipes/merging** — the stubbed economy slice, next obvious step.
3. **Build recipes/merge + content tuning** — currency values, shop reroll odds, and the support
   catalogue are still the spec's open questions.
4. **Harmless noise, not fixed:** a `Lambda capture freed` warning at `mech_actor.gd:543` (the
   landing-dust timer firing during scene teardown on quit) and standard Godot RID cleanup noise on
   forced `quit()`. Neither affects the build; left for a deliberate cleanup pass.
5. Everything is uncommitted on `main` — review and commit when you're happy.
