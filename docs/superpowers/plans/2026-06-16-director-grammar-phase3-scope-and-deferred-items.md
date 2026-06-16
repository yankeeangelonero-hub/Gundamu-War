# Director Grammar — Phase 3 Scope + Deferred Items

> Status: SCOPE / BACKLOG doc, written 2026-06-16 after Phase 2 (Grade node) shipped.
> This is NOT yet a task-by-task implementation plan — it captures the work deferred out of
> Phase 2 so nothing is lost, and sketches the Phase 3 scope per the design spec. Each section
> graduates to its own TDD implementation plan (à la the Phase 1/Phase 2 plans) when picked up.
>
> Authoritative design: `docs/superpowers/specs/2026-06-16-director-grammar-design.md`.
> Phase 2 plan (shipped): `docs/superpowers/plans/2026-06-16-director-grammar-phase2-grade-node.md`.

## Where we are

- **Phase 1 — ShotGrammar extraction:** shipped, parity-locked (golden shot-list hash `2543717900`).
- **Phase 2 — Grade node (Lighting + Color):** shipped. Chromatic fill (F22, with a non-black
  floor), mood variants base/hero/death (F26/F27), FX OmniLights re-enabled incl. ordinary-beam
  muzzle+impact light (F24), one shared `ShotGrammar` instance threaded through shot-gen /
  director runtime / grade / garnish. Determinism intact; the hash is unchanged.

Everything below is **deferred work**, grouped by how soon it should land.

---

## Section A — Phase 2b refinements (small, well-understood; do before the big Phase 3 behaviors)

These came out of the codex spec-check of Phase 2. They are spec-aligned polish, each a few files.

### A1 — Move ambient-fill ownership fully into the Grade/grammar (codex #3, minor)
Today the Grade owns `ambient_light_source` + `ambient_light_color`, but `city_builder.build_environment`
still authors `ambient_light_energy = 1.6` (and the initial source/color). Per the spec's
lighting-ownership split, the **Grade/grammar should own the entire ambient fill** (source, color,
energy), leaving `city_builder` to own only the GI/SDFGI solve, background, fog, and the static
directional + sky.
- Add `ambient_energy` to the `ShotGrammar` Lighting block (default `1.6` to preserve current look).
- `grade.apply_base()` (and/or `_write`) sets `_env.ambient_light_energy` from the grammar.
- Remove the `ambient_light_energy` / ambient source+color authoring from `city_builder` (leave GI,
  background, fog, directional).
- Test: the live env's ambient energy equals the grammar value after `apply_base`; boot smoke; hash
  unchanged.

### A2 — Fuller F26 color shape: base palette, named aftermath, return-to-base (codex #5, minor)
Phase 2 intentionally shipped only `base`/`hero`/`death` moods. The spec's F26 wants a fuller shape:
- An explicit **base palette** (the canonical neutral the moods modulate around) — partly implicit
  in `base` today; make it first-class if the spec demands it.
- A named **`aftermath`** mood for the post-kill smoulder coverage (distinct from the instantaneous
  `death` push).
- A **return-to-base trigger**: moods are currently *sticky* (they persist until the next mapped
  beat). Decide and implement whether hero/death should relax back to base after N seconds or on a
  designated "calm" beat. This is a design call first — confirm the intended behavior against the
  spec before building. (If sticky-until-next-beat is in fact correct, record that decision and
  close the item.)

---

## Section B — Seams carried from earlier phases (close when their trigger arrives)

### B1 — Single-source grammar for CUSTOM grammars (Phase 1 + Phase 2 seam)
Phase 2 made `main.gd` thread ONE `ShotGrammar.default()` instance through shot-gen, the director's
runtime `_grammar` (via `director.set("_grammar", grammar)`), the Grade node, and garnish. This is
correct at defaults. When the **FeelProfile / authored custom grammars** land (they make grammar
values diverge from `default()`), the wiring must be made first-class and enforced: give the director
a single grammar source (a real setter or a `start(...)` parameter rather than the dynamic
`.set("_grammar", ...)` reach-through), and document that any caller passing a custom grammar must
hand the SAME instance to all consumers. Until then, the dynamic-set is an acknowledged, working seam.

### B2 — Extract `melee_cut` timing into the grammar (Phase 1 seam)
The `melee_cut` shot's `t0/t1` (`mt-0.5`, `mt+1.7`) and `time_scale` (`0.5`) are still inline in
`hybrid.gd build_shot_list`, an untunable island versus the grammar-driven Timing block. Extract them
into the `ShotGrammar` Timing block when melee framing is tuned (Phase 3 "melee framing", below).
Note: `hybrid_check.gd` asserts "exactly one shot dilates time" — a non-lethal melee event in a log
would add a second time-dilated shot and break that assertion; revisit it when melee timing is
touched.

> NOTE: the Phase-1 "framing-key `.has()` guard" seam was **closed in Phase 2** (Task 1b) — not
> outstanding.

---

## Section C — Phase 3 proper: new behaviors (per the design spec's build sequence)

The spec sequences Phase 3 as **new director behaviors** (each needs its own design + TDD plan; this
is the scope list, not the implementation):

- **Compression** — pace/density control over the shot list.
- **Impact frames + a time-emphasis arbiter** — a single owner that resolves competing time-scale
  requests (hitstop vs bullet-time vs normal) so they don't fight. NOTE: this is also the right home
  to revisit Grade's `_process` wall-clock compensation — today `delta / current_time_scale()` is
  correct because the director is the *only* thing setting `Engine.time_scale`; once an independent
  hitstop/arbiter exists, confirm the Grade still eases in true wall-clock time (drive it from the
  arbiter's unscaled delta, or `Engine.time_scale`, and add a hitstop transition test). (This is the
  codex #4 item — not a bug today, but it becomes live here.)
- **Staggered blast** — multi-stage explosion staging.
- **Yield-by-class** — weapon-class-dependent reaction/yield.
- **`cockpit_pov`** — the outward-looking cockpit camera primitive (in scope as a camera primitive;
  the cockpit *bond/feedback* system stays deferred to v0.2 pilot-fit).
- **`frame_and_streak`** — framing + streak motion treatment.
- **Melee framing** — tune the melee shots (pairs with B2, the `melee_cut` timing extraction).

Phase 4 (per the spec) is **soft continuity constraints** (F32–F36) — after the new behaviors.

---

## Suggested order when resuming

1. **Section A** (A1, A2) — small, spec-aligned, closes the codex-flagged gaps; cheap wins on the
   proven Grade node.
2. **Section C** behaviors — each as its own design + plan; start with the **time-emphasis arbiter**
   (it unblocks B2 melee timing and resolves the codex #4 wall-clock concern), then the others.
3. **Section B** seams — close B1 when the FeelProfile/custom-grammar work begins; close B2 with
   melee framing.

## Dismissed (not deferred — closed)
- codex #4 "F27 wall-clock stalls during hitstop" as a *current* bug: verified false — the director
  is the only `Engine.time_scale` writer and `current_time_scale()` returns that same value, so
  `delta / ts` already recovers wall-clock delta. It only becomes relevant once an independent
  hitstop exists (folded into the Section C time-emphasis arbiter above).
- codex #6 "mood-map event names may not match schema": verified the names (`fire_buster`,
  `destroyed`, `fire_beam`+`payload.lethal`) against `data/fight_log_everything.json` and the
  `garnish.gd`/`director.gd` readers — they are correct.
