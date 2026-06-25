---
artefact: slice-specification
slice_id: v0.4-slice-01
version: 0.4
slice_number: 1
slice_name: deck-run-model
kind: enabling
status: done
supersedes:
patches:
delivers: []
cites_stories: [US-001]
created_under_schema_version: 0.3.0
cites_behaviours: [BEH-001]
cites_constraints: [ARC-006]
cites_decisions: ["Decided in: Version 0.4"]
cites_actor_flows: []
cites_research:
  - "Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md §Open questions to settle by testing, not by argument"
authored: 2026-06-07
---

# Slice 01 — deck-run-model

## 0. Parent change proposals

None.

## 1. What this slice is

This slice settles the one open mechanic question the dual-layer direction left for playtest: how
the behaviour deck **runs** during a duel. Three candidate run models are on the table —
**construction** (the whole deck is the pilot's always-available repertoire, played by priority;
no draw), **draw** (a hand is drawn each turn from a seeded shuffle, with an energy economy), and
**hybrid** (a deterministic core of always-available behaviours plus a few drawn "opportunity"
cards). The choice shapes the whole feel — whether the duel is faithful to the deck the player
authored, or carries in-fight luck — so it is decided by feel, not by argument.

It is an **enabling** slice: it delivers no player-facing feature directly. Its output is a
recorded, evidenced **decision** (an ADR) plus a written runtime contract for the chosen model.
It unblocks the later combat-core slice (planned `Slice 02 — dual-layer combat core`), which
implements the chosen model, and through it the Doctrine bench and Watch slices.

Technical shape: extend the existing web feel-test harness `experiments/dual-layer-deck-combat.html`
(which already implements all three modes behind a toggle and a seeded RNG) so the three modes can
be compared rigorously on identical inputs and their determinism checked; run a fixed comparison
set; record the decision.

## 2. Vocabulary

- **Run model** — how the authored deck is consumed at runtime during a duel: `construction`,
  `draw`, or `hybrid`.
- **Comparison set** — a small fixed collection of (body, deck, rival, seed) matchups used to
  compare the three run models on equal footing.

## 3. Behaviour

The actor here is the **Engineer (Player)** acting as playtester, plus the design owner who makes
the call.

1. The playtester opens the harness and builds a fixed reference body and deck and fixes a seed.
2. They run the duel in each of the three run models without changing body, deck, rival, or seed,
   and read the event log and result for each.
3. They repeat across the comparison set of matchups and capture, per matchup × model, the
   outcome and qualitative notes on three axes: **legibility** (can you read *why* she did what
   she did and won/lost), **variance** (how much the result swings run-to-run), and
   **authored-intent fidelity** (does she fight the way the deck says).
4. Each model is checked for determinism: the same inputs and seed must reproduce a byte-identical
   event sequence — including `draw`'s seeded shuffle (BEH-001). A model that fails this is not
   eligible to be chosen until the non-determinism is fixed (the recovery path).
5. The owner reviews the comparison and chooses a run model.
6. The decision is recorded as an ADR (via `vouse-research`) naming the chosen model and the
   rationale, explicitly covering how it serves authored-intent legibility and async-PvP fairness;
   the runtime contract for how the deck is consumed in the chosen model is written down for the
   combat-core slice to implement. The chosen model's compiled form must remain a small restricted
   deterministic representation (ARC-006).

Edge/failure: if `draw` or `hybrid` cannot be made deterministic under a fixed seed, that model is
disqualified and the divergence is recorded; the slice still completes by choosing among the
eligible models.

## 4. Surfaces and controls

The harness already provides: body pickers (frame/weapon/support with a weight/power budget), a
deck builder (body-gated cards), a mode toggle (Construction / Draw / Hybrid), a seed field, a
deploy button, a range-line playback, an event log, and a debrief. This slice may add only what
the comparison needs — e.g. a way to export/capture a run's event log as text for diffing. No new
player-facing feature surface is in scope.

## 5. Data and integration notes

Current Architecture has no as-built dual-layer sections, so this slice inherits no architecture
and writes none — its artefact is a decision. The harness is self-contained (no backend, no
external assets). The chosen run model and its runtime contract become inputs to
`Slice 02`. The comparison evidence and the ADR are the durable outputs.

## 6. Acceptance checks

### AC-1 — All three run models are playable and comparable on identical inputs
- **Setup:** Open the harness; build a fixed reference body + deck; set a fixed seed; fix the rival.
- **Action:** Run the duel once in each model (construction, draw, hybrid) changing nothing but the model toggle.
- **Observable signal:** The event log + result for each of the three runs, captured to text.
- **Expected value:** All three produce a complete duel and a result; the run model is the only varied input across the three captures.
- **Evidence artifact:** Three captured run logs saved under `Project Version/Version 0.4/Slices/Unit Tests/evidence/`.

### AC-2 — Each run model is deterministic
- **Setup:** Fixed body + deck + rival + seed; one model.
- **Action:** Run the duel twice in that model with the same seed (including draw's seeded shuffle); repeat for all three models.
- **Observable signal:** A normalized text dump of the event sequence for each run.
- **Expected value:** The two dumps are byte-identical for each model (BEH-001).
- **Evidence artifact:** Paired dumps + a diff showing no differences, per model, under the evidence folder.

### AC-3 — A documented comparison is produced across the comparison set
- **Setup:** A fixed comparison set of at least three (body, deck, rival, seed) matchups.
- **Action:** Run each matchup in all three models; record outcome plus notes on legibility, variance, and authored-intent fidelity.
- **Observable signal:** A comparison table (matchup × model → outcome + notes).
- **Expected value:** The table is complete for every matchup × model and surfaces how the models differ on the three axes.
- **Evidence artifact:** The comparison document saved under the slice's Unit Tests folder.

### AC-4 — The decision is recorded as an ADR
- **Setup:** The AC-3 comparison and the owner's playtest are complete.
- **Action:** Record the chosen run model and rationale as an ADR via `vouse-research`.
- **Observable signal:** The ADR file in `Research/Research Documents/`.
- **Expected value:** A frozen ADR (`kind: adr`) names the chosen model and gives a rationale covering authored-intent legibility and async-PvP fairness; the wishlist open-question entry can be marked resolved by citation.
- **Evidence artifact:** The ADR path, cited in the Unit Test Record.

### AC-5 — A non-deterministic model is detected and blocked (failure/recovery path)
- **Setup:** Run the AC-2 determinism check against a model; deliberately include the known risk case (an unseeded shuffle would diverge under the same seed).
- **Action:** Execute the two same-seed runs and diff them.
- **Observable signal:** The diff output.
- **Expected value:** Any divergence is detected by the diff and disqualifies that model from selection until fixed; after threading the seed correctly, the re-run diff is clean and the model becomes eligible (recovery).
- **Evidence artifact:** The failing diff (if one occurred) and the subsequent clean diff, under the evidence folder.

## 7. Out of scope

- Implementing the chosen run model in the deterministic combat core — owned by `Slice 02`.
- The Hangar body-authoring and Doctrine-bench deck-authoring feature surfaces — the planned Hangar and Doctrine-bench slices (03/04).
- Any Godot work or the M0 stack spike — separate (the harness is web).
- Final card content, balance, or the part/card library size.

## 8. Open questions

Non-blocking for draft:

1. Exact size and membership of the comparison set (recommendation: 3–5 matchups spanning aligned, misaligned, and counter-build cases).
2. Whether the harness should export logs to a file or to clipboard for diffing (recommendation: a copy-to-clipboard "dump events" control; cheapest).

Blocking before `ready`:

1. Owner acknowledges the §6 acceptance checks match intent (the spec moves to `ready` only on explicit owner approval).
