# Opus Vouse Version 0.2 Authoring Report

**Author:** Claude Code (Opus 4.8)
**Date:** 2026-06-05
**Task:** Author next-version planning artefacts in repo-local Vouse format for the warfront + pilot + grid-vs-gear direction. No prototype code.

---

## 1. Lifecycle / routing verdict

Version 0.2 was authored as **draft-proposed, not formally open**.

The Vouse `vouse-managing-versions` open-version preconditions require the previous version to be closed with recorded owner approval before a new version opens. Version 0.1 fails those preconditions:

- `Version Log.md` lists Version 0.1 as **In progress** with no completion entry and no recorded owner approval.
- The close protocol steps for 0.1 have not run: no project-wide architecture drift check, no journey audit, no close-time Kanban board walk, no Roadmap reconciliation.
- `Roadmap.md` milestone **M1 — V0.1 Playable Loop** is still `Not started`, even though all seven 0.1 slices read `Verified` on the Kanban — a reconciliation gap that the 0.1 close is supposed to fix.
- Two 0.1 slices (06, 07) are marked `Verified (needs browser smoke)` — a soft caveat the owner should confirm at close.

The Vouse refusal protocol is explicit: "Asked to open a new version while the previous is still open: refuse and list what blocks the previous close." So I did not open Version 0.2 and did not close Version 0.1 (the task also forbids closing 0.1 without explicit owner approval).

Instead I took the safe documentation path the task allows: a complete Version 0.2 spec with `status: draft-proposed`. The frontmatter and a top "Lifecycle status" section state plainly that it is proposed pending 0.1 close, that `draft-proposed` is a deliberate non-canonical status, and that on formal open the status flips to `open`, candidate IDs are ratified into the High Level Spec, and a Roadmap track is added.

**Cross-version discipline kept:** I did not edit any Version 0.1 slice artefact, the High Level Spec's permanent FEAT/BEH/ARC lists, the Roadmap milestones, or the Version Log. The new FEAT-008..013 and the four proposed invariants live only inside the draft spec, marked proposed, to be ratified at formal open. No frozen Research Document was edited.

## 2. Files created / changed

Created:

- `Project Version/Version 0.2/Version 0_2 Project Specifications.md` — the draft-proposed Version Spec.
- `Project Version/Version 0.2/Slices/` (with `.gitkeep` describing what lands there).
- `Project Version/Version 0.2/Slices/Implementation/` (with `.gitkeep`).
- `Project Version/Version 0.2/Slices/Unit Tests/` (with `.gitkeep`).
- `agent-handoffs/opus-vouse-version-0-2-authoring-report.md` — this report.

Changed (living indices only):

- `Research/User Journeys.md` — added a pointer in §Next-version test flag that Journeys 7–11 are adopted as the test set, carried by the V0.2 draft spec (Slices 02–07 build the surfaces, Slice 08 is the decision gate).
- `Research/Research Catalogue.md` — added a "Carried into" line on the warfront/pilot/grid-vs-gear concept-handoff entry, and a note under Open research questions routing the grid-vs-gear, deterministic-vs-LLM, and pilot-injury questions into the V0.2 draft while keeping them open until Slice 08.

No slice spec files were written. Per `vouse-managing-versions`, slice specs are authored by `vouse-slice-lifecycle` in plan mode after the version is open; that step is deferred until formal open.

Validation run: `check_voice.py` reports **clean** on the Version Spec and both edited indices.

## 3. Version 0.2 goal and slice list

Goal:

> Validate whether Mech Bags should remain a body-part backpack-grid builder or pivot toward gear/mech customisation by testing both surfaces inside a small persistent warfront + pilot-risk loop.

It is a concept-validation version, browser-only, no backend (`ARC-002` extended to the warfront). Eight slices:

1. **Slice 01 — Warfront state and war tick** (enabling). Local deterministic warfront data + pure `advanceWarTick(state, seed)`; determinism is testable here (same seed + prior state → byte-equal next state). Delivers: [].
2. **Slice 02 — Warfront board and state-driven mission board** (feature). Render state; a war tick visibly changes the mission board. Journey 7. Delivers: [FEAT-008, FEAT-009].
3. **Slice 03 — Pilot profile and pre-deployment risk readout** (feature). At least one pilot; readable deployment risk before commit, computed from mission danger + mech protection + pilot state. Journey 9 (1–3). Delivers: [FEAT-010].
4. **Slice 04 — Post-mission pilot outcome ladder** (feature). Injury ladder applied from outcome + risk inputs + seed; out-of-service possible, killed/retired rare; explainable from shown inputs. Journey 9 (4–6). Delivers: [FEAT-011].
5. **Slice 05 — Grid build-surface mission-fit prototype** (feature). Reuse the 0.1 five-bag grid as surface A; connect build to mission suitability + pilot-risk cue; `BEH-001` still holds. Journeys 8, 11. Delivers: [FEAT-012].
6. **Slice 06 — Gear customisation comparison surface** (feature). Surface B: low-fidelity frame/cockpit/armor/weapons/sensors; same brief, same read-out contract as Slice 05. Journeys 8, 11. Delivers: [FEAT-012].
7. **Slice 07 — War report and title/reward from deterministic facts** (feature). Deterministic facts → templated/LLM-style anime briefing + reward/title progress, each title tied to a recorded deed. Journey 10. Delivers: [FEAT-013].
8. **Slice 08 — Comparative journey test and build-surface decision gate** (enabling). Walk Journeys 7–11 through both surfaces on the same brief, capture evidence on the five dimensions, write the keep-grid / pivot-to-gear / hybridize recommendation. Delivers: []. Depends on 02–07.

Slice-sizing gate: each feature slice is demoable on its own and scoped to roughly one session; the two enabling slices (01 backbone, 08 evidence gate) have verifiable signals (byte-equal determinism for 01; a filled evidence matrix + written recommendation for 08). The pilot work is split into risk-in (03) and outcome-transition (04), and the warfront work is split into deterministic backbone (01) and visible board (02), following the "feature that does too much → feature + enabling" split rather than packing a session-and-a-half into one slice.

## 4. How the grid-vs-gear fork is flagged as a required test

The fork is encoded as an evidence gate, never decided in prose:

- It **is** the version goal (keep grid vs pivot to gear, decided by test).
- A proposed invariant requires both surfaces to take an **identical mission brief and identical suitability/pilot-risk read-out contract**, so the comparison measures the surface and not the content.
- Slice 05 (grid) and Slice 06 (gear) are built as siblings against the same brief; neither is privileged.
- Slice 08 is the decision gate: it walks Journeys 7–11 through both surfaces, scores the five evidence dimensions from `Research/User Journeys.md` §Next-version test flag, and writes one of three verdicts — keep grid, pivot to gear, hybridize.
- Acceptance criterion 7 and the Definition of done both require the recorded comparison + recommendation before the version can be considered complete.
- The "What this version does not include" section explicitly defers the final surface commitment to the owner after Slice 08.

## 5. Changes to Research living documents

`Research/User Journeys.md`: one addition in §Next-version test flag stating Journeys 7–11 are the adopted test set and naming the V0.2 draft spec as the plan that carries them (Slices 02–07 build, Slice 08 decides), with the note that the journeys remain source of truth until the version is formally opened. No journey content was rewritten.

`Research/Research Catalogue.md`: a "Carried into" line on the warfront/pilot/grid-vs-gear concept-handoff entry pointing at the V0.2 draft spec and summarising how the version treats the fork; plus a note under Open research questions routing the grid-vs-gear, deterministic-vs-LLM-narration, and non-punitive-pilot-injury questions into V0.2 while keeping them open until Slice 08, and clarifying that V0.2 does not resolve the broader spine question (build vs warfront vs loot vs pilot).

Both edits are to living indices only. Frozen Research Documents were not touched.

## 6. Remaining decisions for Xuanyue before implementation

Lifecycle:

1. **Close Version 0.1?** Approve running the 0.1 close protocol (drift check, journey audit, Kanban walk, Roadmap M1 reconciliation, Version Log entry + approval). Until then V0.2 cannot formally open. Confirm whether the "needs browser smoke" caveat on Slices 06/07 is satisfied.
2. **Ratify the proposed IDs on open.** FEAT-008..013 and the four proposed invariants are draft-only. On formal open, decide which become permanent BEH/ARC (`Decided in: Version 0.2`) and approve adding a Version 0.2 track to the Roadmap.

Scope / design (needed before slice planning):

3. **Warfront granularity.** How small is "small" — how many territories/towns, and does the war advance by an explicit player-triggered tick or by a notional day cycle within the tab?
4. **Pilot count.** One pilot for the spike, or two so specialty/risk-tolerance differences are visible (Journey 9 reads better with at least two)?
5. **Injury-ladder tuning.** Confirm the ladder rungs and the rarity ceiling for killed/retired, and the inputs that move severity (mission danger, mech protection, safety gear, pilot experience, desperate-sortie choice).
6. **Narration source for Slice 07.** Real LLM call vs templated stand-in for the briefing copy. Either satisfies the deterministic-facts/separate-narration split; the choice affects whether any external call appears (it must not decide outcomes, and must not break `ARC-002` for normal play).
7. **Gear-surface fidelity.** Confirm the gear slots to expose (frame/cockpit/armor/weapons/sensors as drafted, or a different set) so Slice 06 stays a fair comparison and not a generic loadout screen.
8. **Evidence rubric for Slice 08.** Confirm the five evidence dimensions are the right scoring axes, and how a verdict is reached (per-dimension winner tally, weighted, or owner judgement on the assembled evidence).

Nothing in this draft commits any of the above; each is surfaced so the owner decides before slice-lifecycle planning begins.
