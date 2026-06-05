# Opus Agent Task — Mech Bags essential-loop distillation

You are Claude Code Opus running inside `D:/Claude/Mech Bags`.

Xuanyue said: “Send the journey to opus for a distillation pass, I want to start with the essential loop without too many systems.”

## Goal

Distill the current Warfront + Pilot + Build-Surface direction into the **smallest essential playable loop**. The owner wants fewer systems, less conceptual sprawl, and a clear starting loop that can be built/tested before expanding into full warfront, NPCs, towns, seasonal rewards, global thousands-of-mechs simulation, etc.

Do **not** implement code. This is a product/design/Vouse planning distillation pass.

## Required reading

Read:
- `Readme.md`
- `High Level Project Specifications.md`
- `Roadmap.md`
- `Kanban.md`
- `Version Log.md`
- `Research/User Journeys.md`
- `Research/Research Catalogue.md`
- `Research/Research Documents/concept-handoff-2026-06-05-backpack-autobattler-meta.md`
- `Research/Research Documents/concept-handoff-2026-06-05-warfront-pilot-grid-vs-gear.md`
- `Project Version/Version 0.2/Version 0_2 Project Specifications.md`
- `agent-handoffs/opus-vouse-version-0-2-authoring-report.md`

## Distillation target

The essential loop should likely preserve only the minimum that makes the concept different from plain mech PVP:

- A mission context changes what build is good.
- A pilot has visible risk/condition, creating stakes.
- The player adjusts a mech build.
- The mission resolves deterministically.
- A short report explains outcome, pilot consequence, and reward/progress.
- The next mission/condition gives a reason to adjust again.

Everything else is candidate deferral unless required to prove the loop:
- global warfront with thousands of mechs;
- detailed territory/town capture;
- many anime NPCs;
- long seasonal reward structure;
- real LLM live narration;
- real backend/multiplayer;
- large injury model;
- many pilots;
- both grid and gear surfaces at high fidelity.

## Questions to answer

1. What is the **one-sentence essential loop**?
2. What are the **minimum player steps** from opening the game to completing one loop?
3. What systems are truly essential for the first version of this loop?
4. What systems should be explicitly deferred?
5. Does the grid-vs-gear comparison still belong in the first essential loop, or should it be reduced to a paper/low-fi comparison while one surface remains playable?
6. What is the smallest possible V0.2/MVP slice sequence after distillation?
7. What user journey should be the primary journey for this distilled version?
8. What acceptance criteria prove “the loop works” without building too many systems?

## Output requirements

Write a report:

`agent-handoffs/opus-essential-loop-distillation-report.md`

The report must include:

1. Executive recommendation — what to cut and what to keep.
2. One-sentence essential loop.
3. Minimal player journey, step by step.
4. Essential systems vs deferred systems table.
5. Recommended revised V0.2 scope/slices.
6. Grid-vs-gear recommendation for this stage: playable comparison, low-fi comparison, or defer.
7. Risks if we overbuild.
8. What to update in Vouse docs next, if Xuanyue approves.

## Optional doc updates

Do **not** rewrite the Version 0.2 spec unless the distillation is obviously safe and small. Prefer writing the report first. If you do make doc edits, keep them limited to a short `Research/User Journeys.md` addendum or `Research/Research Catalogue.md` note, and list exactly what changed.

## Constraints

- Do not implement code.
- Do not close Version 0.1.
- Do not formally open Version 0.2.
- Do not decide a large new architecture.
- Preserve the owner’s preference: project state lives in the project folder; no external vault writes.
- Keep the output practical and ruthless: the point is fewer systems, faster proof.
