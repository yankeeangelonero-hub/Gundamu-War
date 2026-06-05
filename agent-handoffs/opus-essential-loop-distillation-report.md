# Opus Essential-Loop Distillation Report

**Author:** Claude Code (Opus 4.8)
**Date:** 2026-06-05
**Task:** Distill the Warfront + Pilot + Build-Surface direction down to the smallest essential playable loop. Product/design/Vouse planning only — no code, no version lifecycle changes.
**Requested by:** Xuanyue — "Send the journey to opus for a distillation pass, I want to start with the essential loop without too many systems."

---

## 1. Executive recommendation — what to cut and what to keep

The draft Version 0.2 spec is well-built, but it is **trying to answer two questions at once**, and one of them is premature:

- **Q1 — Is the warfront + pilot loop actually compelling?** (Does mission context + pilot stakes make build-tuning feel different from plain mech PVP?)
- **Q2 — Grid surface or gear surface?** (Which build interface communicates mission-fit and pilot-risk better?)

The current draft makes **Q2 the spine** — the version *goal* is the grid-vs-gear comparison, Slice 08 is the decision gate, and Slices 05/06 build two full build surfaces. But **Q2 cannot be meaningfully answered until Q1 is true.** If the mission+pilot loop isn't fun, it doesn't matter which surface you tune it on; if it *is* fun, you already have a working grid surface from V0.1 to prove it. Building a second surface first doubles the build-surface workload to answer the wrong question early.

**Distillation verdict: make Q1 the spine. Prove the loop on the build surface you already have. Reduce grid-vs-gear to a paper comparison and re-open it as its own evaluation only after the loop is validated.**

Concretely:

**KEEP (and mostly reuse what already ships in V0.1):**
- The existing five-bag grid build surface — reuse, do not rebuild, do not duplicate.
- The existing deterministic ATB simulator and result overlay — reuse, extend lightly.
- A **mission context** that changes what build is good (1–2 condition tags + a danger level) and a visible **suitability read-out**.
- **One pilot** with a small condition state and a **pre-deployment risk read-out**.
- A **post-mission consequence**: outcome → pilot condition change (collapsed ladder) → reward, in a short report.
- A **short authored mission sequence** (3 missions) so the *next* mission's different condition gives a concrete reason to re-tune.

**CUT / DEFER (everything that is flavour, retention scaffolding, or a second answer to a question we haven't earned yet):**
- The warfront territory/town/pressure map and `advanceWarTick` over a map (FEAT-008/009 as drafted). Replace with a thin mission sequence.
- The second (gear) build surface (FEAT-012's gear half) — paper comparison only.
- LLM live narration — use templated copy.
- The full 6-rung injury ladder with MIA and killed/retired — collapse to 3–4 readable states.
- Titles / medals / seasonal skins / exclusive parts (FEAT-013's title layer) — defer.
- Multiple pilots, NPC squads, loot economy, async PVP pool, backend.

This drops V0.2 from **6 proposed FEATs / 8 slices** to roughly **4 capabilities / 3 build slices + 1 evaluation step**, while still exercising the exact thing that makes Mech Bags different from a plain autobattler: *the build you bring has to change because of the mission, and there's a person inside the machine.*

---

## 2. One-sentence essential loop

> **Each mission's conditions and your pilot's risk pressure you to re-tune one persistent mech build, which resolves deterministically into a short report of outcome, pilot consequence, and reward — and the next mission's different condition tells you what to change again.**

---

## 3. Minimal player journey, step by step

From cold open to one completed loop:

1. **Open the game.** See the current **mission brief**: 1–2 condition tags (e.g. *Long-range engagement* → ranged favoured; *Ambush terrain* → armour favoured) and a **danger level**. See your **pilot's condition** (e.g. Fresh).
2. See a **suitability read-out** for this mission against your current build ("Ranged-favoured — your build is light on ranged. Fit: Low").
3. **Edit the build** on the existing five-bag grid to improve fit and/or protection.
4. As you change protection, the **pre-deployment pilot risk** updates ("Risk: Moderate").
5. **Deploy.**
6. **Watch the deterministic ATB battle** (reused from V0.1) or Skip.
7. Read the **report**: win/loss + the main reason, the **pilot consequence** (new condition + *why*), and the **reward**.
8. **Advance.** The next mission shows a **different condition**, giving a concrete reason to re-tune. Loop back to step 2.

The loop is closed at step 8: the player has a reason to change the build that comes from outside their own optimisation, plus a stake (the pilot) that makes "just bring max damage" a real tradeoff.

---

## 4. Essential systems vs deferred systems

| System | Verdict | Notes |
|---|---|---|
| Five-bag grid build surface | **Essential — reuse** | Ships in V0.1. Do not rebuild or duplicate. `BEH-001` still holds. |
| Deterministic ATB simulator + result overlay | **Essential — reuse** | `simulate(build, enemy, seed)` already exists. Mission supplies enemy build + condition modifier. |
| Mission context (1–2 condition tags + danger) | **Essential — new, thin** | This is the "what build is good changes" pillar. Data, not a map. |
| Build-suitability read-out | **Essential — new, thin** | Makes mission-fit legible while editing. |
| Single pilot + condition state | **Essential — new, thin** | One pilot. Collapsed condition states (Fresh / Fatigued / Wounded / Out of service). |
| Pre-deployment pilot risk read-out | **Essential — new, thin** | Same value the post-mission step consumes. The "stakes" pillar. |
| Post-mission consequence (condition + reward) | **Essential — new, thin** | Outcome → condition transition (explainable) + simple reward. |
| Short authored mission sequence (≈3) | **Essential — data** | Closes the loop: next mission's different condition = reason to re-tune. |
| After-action report (outcome + reason + pilot + reward) | **Essential — extend overlay** | Extend the existing result overlay; templated copy. |
| --- | --- | --- |
| Warfront territory/town/pressure map + war tick | **Defer** | Flavour until the loop is fun. A mission sequence carries the loop without a map. |
| Gear (second) build surface | **Defer — paper only** | Doubles build work; answers Q2 before Q1 is proven. |
| LLM live war-director narration | **Defer — templates** | Nondeterminism, latency, external-call risk; templates prove the deterministic/narration split fine. |
| Full 6-rung injury ladder, MIA, killed/retired | **Defer** | Collapse to 3–4 states; permadeath is a balancing rabbit-hole and an "afraid to experiment" risk before stakes are validated. |
| Titles / medals / seasonal skins / exclusive parts | **Defer** | Retention scaffolding for a loop that doesn't exist yet. |
| Multiple pilots, NPC squads | **Defer** | One pilot proves the stake; more is content authoring with no added proof. |
| Loot economy / scavenged parts | **Defer** | Belongs to the persistent-meta question, not the essential loop. |
| Async offline PVP pool, backend, accounts | **Defer** | Out of prototype scope; `ARC-002` holds. |

---

## 5. Recommended revised V0.2 scope / slices

Keep V0.2 as the concept-validation version, but make its spine **"is the mission+pilot loop compelling on the surface we already have?"** Three build slices plus one evaluation step:

**Slice 01 — Mission context + build suitability.**
Author a small ordered sequence of ≈3 missions, each a data record: enemy build (from the existing pool) + 1–2 condition tags + a danger level. Apply the condition as a simple deterministic modifier in the existing simulator. Show a **suitability read-out** against the current grid build. Reuses the grid and ATB sim. *This is the "what build is good changes" pillar.* Serves a distilled Journey 8.

**Slice 02 — Pilot condition + pre-deployment risk.**
One pilot with a condition state (Fresh / Fatigued / Wounded / Out of service). Compute and show a **deployment risk** before commit, deterministically from mission danger + build protection + pilot condition. The shown value is the one Slice 03 consumes. *This is the "stakes" pillar.* Serves a distilled Journey 9 (steps 1–3).

**Slice 03 — Deterministic resolve → report → consequence → advance.**
Run the mission deterministically (same build + seed → same result). Write the **after-action report**: outcome, main reason (suitability + key events), **pilot consequence** (condition transition + *why*), and **reward**. Apply the condition transition (out-of-service forces a rest; no permadeath). **Advance** to the next mission, which presents a different condition. *This closes the loop.* Serves distilled Journeys 8 + 9 (steps 4–6) and the loop-completion goal.

**Slice 04 — Playtest + decision (evaluation, not a build slice).**
Play the 3-mission sequence and record evidence against the loop's acceptance criteria (§7): does adaptation pressure exist, are the stakes felt, is the report legible? Plus a **one-page paper grid-vs-gear comparison** (how each surface *would* express mission-fit and pilot-risk) — no second surface is built. Output: a short "loop validated / not yet / pivot" note and a recommendation on whether to invest in the gear surface next.

Proposed FEATs shrink to about four:
- FEAT-A — Mission context with conditions + suitability read-out (absorbs the useful half of FEAT-009; drops the map half of FEAT-008).
- FEAT-B — Single pilot with pre-deployment risk read-out (FEAT-010, scoped down).
- FEAT-C — Post-mission consequence: collapsed condition ladder + reward (FEAT-011, collapsed; reward without titles).
- FEAT-D — After-action report from deterministic facts, templated copy (FEAT-013 minus the title/LLM layer).

FEAT-012 (two surfaces) is **dropped from the build** and recorded as a paper comparison.

Proposed invariants worth keeping (others defer with their systems):
- **Deterministic resolution, separated narration** — outcome facts are deterministic; report copy reads facts and may not alter them. (The useful core of the drafted deterministic-war-truth invariant, minus the map.)
- **Pilot risk is visible before deployment** and is the same value consumed afterward.
- **Pilot harm is legible, not punitive or random** — explainable from shown inputs; no common permadeath.

---

## 6. Grid-vs-gear recommendation for this stage

**Defer to a paper / low-fi comparison. Keep the grid playable (reuse V0.1).**

Reasoning:
- The fork is a *real* strategic question, but it is **downstream of loop-fun**. You can only judge "which surface communicates mission-fit and pilot-risk better" once mission-fit and pilot-risk are things the loop actually produces and the loop is worth playing.
- We already have a working, playtested grid surface. Building a second full surface to compare them is the single largest source of sprawl in the current draft and front-loads the most expensive work.
- A one-page paper comparison (Slice 04) — *how would each surface express the suitability read-out and the pilot-risk read-out?* — captures the design thinking cheaply and keeps the fork explicitly open without spending a build slice on it.
- Re-open the build-surface comparison as its **own** small version *after* the loop is validated, if and only if Slice 04 says the loop is worth building a surface comparison for.

This honours the concept handoff's instruction not to decide the fork in prose — it stays open as a recorded, deferred test — while refusing to pay for it before the prerequisite is met.

---

## 7. Acceptance criteria — "the loop works" without overbuilding

Each is checkable in-browser with the 3-mission sequence, no backend:

1. **Adaptation pressure exists.** Two consecutive missions favour different conditions, and a build that reads "good fit" for mission A reads worse fit for mission B without the player changing it.
2. **Fit is legible and responsive.** Editing the build to match the mission visibly improves the suitability read-out.
3. **Risk is visible and consistent.** Pilot deployment risk is shown before commit and is the exact value the post-mission step consumes.
4. **Stakes are real but fair.** A risky mission or poorly-protected build can move the pilot to a worse condition; the change is explainable from the shown inputs; there is no common permadeath.
5. **Determinism holds.** Same build + same seed → identical result and identical report (byte-equal), across repeated runs.
6. **The report closes the gap.** It states outcome, the main reason, the pilot consequence *and why*, and the reward — without inspecting internals (`BEH-005` extended to the pilot line).
7. **The loop re-arms.** After a mission, the next mission presents a different condition, giving a concrete reason to re-tune.
8. **No backend.** The whole loop runs in the browser tab with no external call (`ARC-002`).

If 1, 4, and 7 all hold and feel good in playtest, the loop is differentiated from plain mech PVP. That is the whole bet.

---

## 8. Risks if we overbuild

- **Warfront-map-first burns the budget before the loop is proven.** A territory/town/pressure map is flavour wrapped around the loop; if the loop isn't fun, the map is a beautiful frame around nothing. Prove the loop with a mission sequence first.
- **Two surfaces answers the wrong question first.** Building grid *and* gear before the loop is validated doubles the most expensive work to resolve Q2 while Q1 is still unknown. If the loop flops, both surfaces were wasted.
- **LLM narration adds nondeterminism, latency, and an external-call dependency** that fights `ARC-002` and the determinism invariant, for a payoff (atmosphere) that templated copy delivers well enough to prove the split.
- **A full injury ladder + permadeath invites a balancing rabbit-hole** and risks the exact failure mode the handoff warns about — players too afraid to experiment — before we've even confirmed the stake lands. Collapse it; tune later.
- **Titles / seasonal rewards are retention scaffolding for a loop that doesn't exist yet.** Building them now optimises retention on an unproven core.
- **Many pilots / NPCs multiply content authoring with zero added proof.** One pilot proves the stake; the second pilot is a V-next concern.
- **Net risk:** the draft's 8 slices spend most of the budget on flavour and on a premature surface comparison, leaving the actual differentiator (mission pressure + pilot stakes) as just two of eight slices. Distilling inverts that ratio: ~all of the budget goes to the differentiator.

---

## What to update in Vouse docs next, if Xuanyue approves

These are **proposed**, not done. Listed in dependency order. (Lifecycle reality unchanged from the prior authoring report: **Version 0.1 still must be owner-closed before Version 0.2 can formally open** — the close protocol, M1/Version Log reconciliation, and the Slice 06/07 "needs browser smoke" caveat are all still outstanding.)

1. **`Project Version/Version 0.2/Version 0_2 Project Specifications.md`** (safe to edit — it is `draft-proposed`, not formally open): replace the scope/slice section with the distilled spine. 6 FEATs → ~4 (A–D above); 8 slices → 3 build + 1 evaluation; drop the warfront-map half of FEAT-008/009; drop the gear surface from the build (paper comparison only); collapse the injury ladder; remove the title/LLM layers. Re-point the goal line to "validate the mission+pilot loop on the existing grid surface" with grid-vs-gear recorded as a deferred downstream test.
2. **`Research/User Journeys.md`**: add a short **Journey 12 — Essential loop (adapt for the mission, mind the pilot)** as the *primary* journey for the distilled version, and annotate Journeys 7 (warfront map), 10 (war hero / titles), and 11 (grid-vs-gear comparison) as **deferred beyond the essential loop**. Journeys 8 and 9 remain, in distilled form.
3. **`Research/Research Catalogue.md`**: update the routing note so the grid-vs-gear question is recorded as **deferred until the loop is validated** rather than tested inside V0.2, and note that V0.2's scope is now loop-validation-first.

Per the task's "prefer report first" guidance, I have made only the two smallest, clearly-safe living-index edits below and left the V0.2 spec rewrite (item 1) for explicit owner approval. Edits made this session are listed in the next section.

---

## Doc edits made this session

Limited to living indices, as the task permits. Listed exactly:

- **`Research/User Journeys.md`** — appended **Journey 12 — Essential loop (adapt for the mission, mind the pilot)** under a new "Distilled essential-loop journey" subsection, and added one line flagging Journeys 7, 10, 11 as deferred beyond the essential loop. No existing journey text rewritten.
- **`Research/Research Catalogue.md`** — added one note under the concept-handoff / open-questions area recording the distillation: loop-validation is sequenced before the grid-vs-gear test, which is deferred until the loop is proven.

No code, no V0.2 spec rewrite, no V0.1 artefacts, no High Level Spec / Roadmap / Version Log edits, no frozen Research Document edits. Version 0.1 is not closed and Version 0.2 is not opened.
