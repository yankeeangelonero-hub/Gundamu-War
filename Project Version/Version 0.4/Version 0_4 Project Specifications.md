---
artefact: version-spec
project: kitbash-mecha
version: 0.4
status: open
opened: 2026-06-07
closed:
slices: [v0.4-slice-01, v0.4-slice-02]
---

# Version 0.4 — Dual-layer essential slice

## What this version ships

The first playable realisation of the dual-layer direction (US-001): the player authors a mech
**body** (kitbash + weight/power budget) and a **mind** (a body-gated behaviour deck), deploys,
and watches a deterministic duel whose outcome is legible from the fight and a debrief. The
version opens by settling the one open mechanic question — the behaviour-deck **run model**
(construction vs draw vs hybrid) — through web playtest, then builds the deterministic core and
the authoring/watch surfaces around the chosen model.

Canonical intent: `Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md`,
`User Stories/US-001.md`, `Research/flows/dual-layer-core-loop.md`.

## Slices

- **Slice 01 — deck-run-model** (`kind: enabling`). Extend the web feel-test harness
  (`experiments/dual-layer-deck-combat.html`) so construction / draw / hybrid are properly
  comparable, play-test them, and record the decision (an ADR) with evidence. Settles the run
  model before the real core is built. Drafted now via `vouse-slice-lifecycle`.
- **Slice 02 — backpack-system-comparator** (`kind: enabling`). Branch-local comparator spec for a
  single-canvas Backpack Battles-style build surface. Tests whether spatial item placement can
  carry the same authorship, determinism, and legible debrief load as the current body-plus-mind
  direction before any canonical pivot is made. Drafted now via `vouse-slice-lifecycle`.

Planned, drafted as the version progresses (not yet committed in frontmatter):

- **Slice 03 — dual-layer combat core** (`kind: enabling`) — the pure `{body, deck, seed}` →
  events + result + debrief engine in the chosen run model; carries the US-001 determinism +
  dead-card spine (BEH-001, BEH-005). Deferred while the branch tests the backpack comparator.
- **Slice 04 — Hangar** (`kind: feature`) — author the body (kitbash + weight/power budget).
- **Slice 05 — Doctrine bench** (`kind: feature`) — author the body-gated behaviour deck.
- **Slice 06 — Watch + debrief** (`kind: feature`) — deploy, watch the duel, read the debrief
  (BEH-004 legibility).

## What this version does not include

The Godot port of the core (pending the M0 stack spike and the run-model decision); the
war/theatre macro layer; multiple opponents; the networked backend and real-player opponents; the
deep Carnage-Heart-style visual behaviour-flow graph. These are deferred — see `Roadmap.md` and
the wishlist.

## Decisions made in this version

- **Deck run model: construction** (Slice 01, 2026-06-07). The behaviour deck is consumed as an
  always-available repertoire played by deck-order priority — no hand, no draw, no per-fight
  shuffle. Decided by playtest evidence (draw was degenerate; construction is faithful, legible,
  and luck-free). Recorded in `Research/Research Documents/adr-2026-06-07-deck-run-model.md`. This
  is the runtime contract the combat-core slice implements.

## Definition of done

- The behaviour-deck run model is decided with playtest evidence (Slice 01).
- The dual-layer essential slice (US-001) is playable: author a body + a deck, deploy, watch, and
  read the debrief.
- The US-001 falsifiable claims are verified: byte-equal determinism from `{body, deck, opponent,
  seed}`; a body-incompatible card is dead and never fires; no outcome is shown without a concrete
  in-fight reason.
- Current Architecture and the canonical docs are updated; owner approves the close.

## Notes from this version

_(empty at open)_
