---
project: kitbash-mecha
repo: gundamu-war
doc_type: roadmap
status: active
updated: 2026-06-06
---

# Roadmap — Kitbash Mecha

The active direction is the v0.4 pilot-fit and war-front design (see Version Log.md and
docs/wishlist/wishlist.md). Earlier prototypes (v0.1 bag-packing, v0.2 single-canvas
theatre, v0.3 kitbash) are built and superseded; their deterministic-sim and
sim-versus-animation foundations carry forward.

## Track: v0.4 — Pilot-fit on Godot

Goal: prove the pilot-fit engine and the deploy decision as a playable test, on the chosen
Godot 4.6 / GDScript stack, then grow the loop toward the war endgame.

---

### M0 — Stack confirmation spike

**Status:** Not started

**Goal:** Confirm Godot 4.6 + GDScript in practice via the throwaway spike in the stack ADR
— a cutout rig from the existing part sprites, runtime part-swap, one authored clip + one FX
strip, a seeded deterministic sim driving it, a headless re-sim diff, and a web export.

**Done when:** the spike confirms part-swap ergonomics, determinism, headless re-sim parity,
and a web build; or it surfaces a reason to fall back to the web-native option in the ADR.

---

### M1 — Deploy-decision test version (KM-DEPLOY)

**Status:** Not started (planning)

**Goal:** The first playable test of the new direction: the deploy gamble — push the pilot
for a breakthrough versus a safe fit — with a pre-deploy fit readout, a minimally legible
watched fight where sync climbs, and a post-fight growth readout. One pilot, one seeded
ghost opponent, no theatre yet.

**Done when:** a tester can fit a mech, read the fit forecast, choose to push or play safe,
watch a legible fight whose outcome traces to the fit, and see the pilot grow — and the
"push her or protect her" choice feels meaningful. Tracks the work-map slice KM-DEPLOY.

---

### M2 — Loop screens around the test

**Status:** Not started (blocked on M1)

**Goal:** Grow the test into the full loop — workshop fit-out (KM-WORKSHOP), duel-watch with
sync visualization (KM-WATCH), homecoming/growth (KM-HOME), and a thin theatre to pick a
front (KM-THEATRE) — sequenced per the work map.

**Done when:** the workshop → deploy → watch → homecoming loop runs in the Godot build and a
web export, with the war as a drifting backdrop.

---

## Future (not planned)

Recorded for awareness; no dates. The networked backend for real-player opponents and the
async-PvP war; the two-faction, game-master-steered live war with developer events; a stable
of multiple pilots; the opt-in pilot-behavior rule layer (and any visual AI beyond it);
grunts in the field; research as a second use for salvage.
