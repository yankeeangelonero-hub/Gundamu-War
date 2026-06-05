# Opus Agent Task — Mech Bags Version 0.2 Vouse next-version authoring

You are Claude Code Opus running inside `D:/Claude/Mech Bags`.

Xuanyue asked: “We have to iterate then whether we should keep the backpack grid system or shift into a more gear and mech customisation system. Either way flag this as something to test in the next version. Pass to opus to use Vouse skills to write the next version. Update the user journey document.”

Hermes has already updated/created these project-folder documents before dispatching you:
- `Research/User Journeys.md`
- `Research/Research Documents/concept-handoff-2026-06-05-warfront-pilot-grid-vs-gear.md`
- `Research/Research Catalogue.md`

Your job is to use the repo-local Vouse-style project structure to author the next-version planning artefacts. Do **not** implement prototype code.

## Coordination and guardrails

- Start with `git status --short` and inspect the repo-local docs. There are uncommitted prototype/design/user-journey changes from previous workers; do not revert or overwrite them.
- Do not commit, push, delete screenshots, or run destructive git commands.
- Do not edit frozen Research Documents. If you need to supersede a frozen document, create a new dated document instead.
- Canonical project state lives inside `D:/Claude/Mech Bags`; do not write to external vaults.
- Use Vouse discipline: version specs and slices should be evidence-oriented, small, and testable.
- If the project’s Vouse lifecycle says Version 0.1 must be formally closed before opening Version 0.2, do the safe documentation path: write a clear Version 0.2 draft/proposed spec and report the lifecycle blocker instead of pretending the close happened. Do not mark Version 0.1 closed without explicit owner approval.

## Required reading

Read at least:
- `CLAUDE.md` if present
- `Readme.md`
- `High Level Project Specifications.md`
- `Roadmap.md`
- `Kanban.md`
- `Version Log.md`
- `Project Version/Version 0.1/Version 0_1 Project Specifications.md`
- `Research/Research Catalogue.md`
- `Research/User Journeys.md`
- `Research/Research Documents/concept-handoff-2026-06-05-backpack-autobattler-meta.md`
- `Research/Research Documents/concept-handoff-2026-06-05-warfront-pilot-grid-vs-gear.md`
- relevant recent reports under `agent-handoffs/` if useful, especially Opus journey and mobile UX reports.

## Vouse guidance to follow

Use these distilled Vouse rules:

### Opening/writing a version
A Version Spec should include:
- version goal in concrete demoable terms;
- scope boundary;
- explicit deferrals/out-of-scope;
- slice list, each slice independently demoable and roughly one work session;
- acceptance criteria / definition of done;
- decisions/open questions for the version;
- citations to research/user-journey docs that motivate the version.

### Slice sizing gate
For each proposed slice, ask:
- Can it produce demoable evidence on its own?
- Can it fit roughly one work session?
- Does it have acceptance criteria that can be tested by a human/browser/tool?

If a slice is too broad, split it.

### Cross-version discipline
This request is cross-version because it changes the next product direction and may change the core build-surface invariant. Do not silently edit Version 0.1 shipped slice artefacts. The next version should carry the experiment forward.

### Research discipline
Frozen Research Documents are not edited. Living indices (`Research/Research Catalogue.md`, `Research/User Journeys.md`) may be updated if you find gaps.

## Product direction to encode

The next version should be a concept-validation version. It should **not** assume the final answer to the grid-vs-gear fork.

Current concept:
- The project may move from plain mech customisation PVP toward a living asynchronous warfront.
- Mechs fight in a simulated campaign front in the background.
- The front, towns, mission board, NPCs, and rewards change over time.
- Players adapt builds in response to daily/warfront conditions.
- The LLM can act as a war director/correspondent, but deterministic state should decide actual territory, mission, pilot, reward, and title outcomes.
- The pilot layer creates stakes: pilots can be fatigued, wounded, out of service, missing, or rarely killed/retired if the mech performs poorly or is sent into high-risk missions.
- The next version must test whether the Backpack-style body-part grid remains the right build surface or whether a gear/mech-customisation surface better supports warfront missions and pilot-risk clarity.

## Expected output artefacts

Author a next-version plan in repo-local Vouse format. Preferred path:

`Project Version/Version 0.2/Version 0_2 Project Specifications.md`

If you judge formal opening is blocked by Vouse lifecycle because Version 0.1 is not owner-closed, still write one of:

`Project Version/Version 0.2/Version 0_2 Project Specifications.md` with `status: draft-proposed`

or

`Project Version/Version 0.2/Version 0_2 Project Specifications - Draft.md`

Be explicit in frontmatter/body that it is proposed pending Version 0.1 close if needed.

Also create any needed directories:
- `Project Version/Version 0.2/Slices/`
- `Project Version/Version 0.2/Slices/Implementation/`
- `Project Version/Version 0.2/Slices/Unit Tests/`

Do not write full slice specs unless you determine that Vouse expects them at version-open draft time and they can be kept concise. If you do draft slice specs, keep them small and clearly testable.

## Candidate Version 0.2 shape

Consider a title like:

**Version 0.2 — Warfront + Pilot Build-Surface Spike**

Possible version goal:

> Validate whether Mech Bags should remain a body-part backpack-grid builder or pivot toward gear/mech customisation by testing both surfaces inside a small persistent warfront + pilot-risk loop.

Candidate slices to evaluate/resize:

1. Warfront state model and daily mission board
   - local deterministic state only;
   - tiny map/territory/town state;
   - mission board changes based on state.

2. Pilot profile, condition, and risk model
   - at least one pilot profile;
   - visible condition/risk before deployment;
   - post-mission outcomes include fatigue/wound/out-of-service states;
   - no punitive common permadeath.

3. Grid build-surface mission-fit prototype
   - keep current body-part grid as one test surface;
   - connect grid build to mission suitability/pilot risk cues.

4. Gear/mech customisation comparison prototype
   - create a second low-fidelity build surface for gear/frame/cockpit/armor/weapons;
   - same mission brief as the grid surface;
   - compare clarity, not final production art.

5. War report / battle report / title-reward prototype
   - deterministic outcome facts;
   - LLM-style or templated anime briefing copy;
   - visible reward/title progress backed by rules.

6. Comparative journey test and decision gate
   - use `Research/User Journeys.md` journeys 7–11;
   - produce evidence and a recommendation: keep grid, pivot to gear, or hybridize.

You may improve this slice list if a better Vouse-sized decomposition emerges.

## Required acceptance criteria themes

The Version 0.2 plan must make these testable:
- player can see a warfront state and changed mission board;
- player can see pilot risk before deploying;
- poor performance can put pilot out of service without feeling random;
- grid-vs-gear surfaces are tested against the same mission brief;
- the version collects evidence for the build-surface decision;
- deterministic state and LLM/narrative output are separated;
- no real backend, accounts, or live multiplayer required.

## Report required

Write:

`agent-handoffs/opus-vouse-version-0-2-authoring-report.md`

Report should include:
1. Lifecycle/routing verdict: whether you treated Version 0.2 as formally open or proposed pending 0.1 close, and why.
2. Files created/changed.
3. Version 0.2 goal and slice list summary.
4. How the grid-vs-gear fork is flagged as a required test.
5. Any changes made to `Research/User Journeys.md` or `Research/Research Catalogue.md`.
6. Remaining decisions Xuanyue must make before implementation.

## Do not do

- Do not implement code or alter `prototype/`.
- Do not close Version 0.1 without explicit owner approval.
- Do not make real networking/backend scope part of Version 0.2.
- Do not decide grid vs gear in prose; make it an evidence gate.
- Do not make pilot death common or random in the spec.
