# Handoff — Cinematic 3D combat direction + KM-DIRECTOR-SPIKE (2026-06-12)

Pause point after a design/brainstorm session that ended with an approved design spec and a
ready-to-execute implementation plan, **not yet executed**. This captures **what is recorded**,
**the decisions made**, **what is pending routing into canon**, and **exactly how to resume**.
Read this first.

---

## 1. The one-paragraph state

The owner feel-tested the backpack comparator (this branch's test target) and pivoted the session
to "how do we make the watched combat visually interesting." Brainstorming ran from the
comparator's instant text-log resolve up to the owner's actual holy grail — an **anime-worthy
cinematic mech battle** (08th MS Team / Char's Counterattack register: giant feel, beams and
ballistics in a city, big explosions, adrenaline) — and landed on a committed presentation
direction: **3D in Godot, deterministic sim authoritative, renderer garnishes, and a "director"
that pre-reads the fight event log and stages camera/spectacle from it**. Mobile was **dropped**
(PC-first all-in); engine stays **Godot 4.6 with a money-shot spike as the exit test** (fail →
Unreal re-opens with a human Niagara tech-artist seat costed in). A design spec is written and
owner-approved, and a 9-task implementation plan for **KM-DIRECTOR-SPIKE** is written and
self-reviewed. Execution has not started — the owner asked for this handoff instead of choosing
an execution mode.

---

## 2. Artifacts written this session (all uncommitted, branch `backpack-system-test`)

| Artefact | Path | Status |
|---|---|---|
| Design spec (direction + spike) | `Research/Research Documents/design-spec-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md` | **owner-approved**, draft frontmatter |
| Implementation plan (9 tasks) | `docs/superpowers/plans/2026-06-12-km-director-spike.md` | ready to execute |
| This handoff | `agent-handoffs/handoff-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md` | — |

Nothing was committed (owner's standing rule: no commits without explicit instruction).
A smoke-test screenshot `backpack-comparator-smoke.png` also landed in the repo root (disposable).

---

## 3. Decisions made (owner-confirmed, in order)

1. **Watch goal = spectacle.** The watched fight optimizes for drama; the debrief carries
   analysis. (Legibility/attachment were explicitly offered and not chosen.)
2. **Presentation is 3D.** Kitbashed player-authored mechs argue *for* 3D (modular parts on a
   procedural rig animate from any camera angle); "polished 2D animation + customization" is a
   structurally bad combination (cutout-puppet ceiling, camera locked to drawn facings).
3. **Mobile target dropped; PC-first all-in.** Owner picked this explicitly over keeping mobile.
4. **Engine: Godot 4.6 stays, with an exit criterion.** Owner has an **engine-agnostic 3D art
   team** (DCC asset producers, no Unreal pipeline specialism). Key reasoning: Unreal's power
   tools (Niagara/Lumen/Sequencer) are GUI-first human-authored; Godot is text-all-the-way-down,
   so coding agents fill the tech-artist seat. Godot ≈ 80% of the cinematic read at the team's
   sustainable art bar; the missing 20% (photoreal GI / RT / Niagara peaks) is what a failed
   spike would buy via Unreal.
5. **Sim stays deterministic and authoritative; renderer garnishes.** Future sim gains *coarse
   space* (owned fixed-point code, never engine physics — preserves byte-identical PvP re-sim).
   Tracers/ricochets/debris are cosmetic, synced to log outcomes.
6. **The director pattern** (the riskiest novel piece): presentation pre-reads the entire
   deterministic event log before playing a frame, so it can stage, frame, and pace like a
   film director who has read the script (slow-mo on the kill it knows is coming, etc.).

Spike pass criteria (frozen in the spec; graded as-is, no "imagine better assets"): scale reads /
involuntary reaction from a non-builder / kill moment lands / stable 60fps mid PC / as-is grading.
Judges: owner + art team + one cold viewer. **Fail → Unreal re-opens.**

---

## 4. Pending canon routing (flagged in the spec, NOT yet applied)

- **No-3D rule** (`CLAUDE.md` "Agents should not", High Level Spec): needs `vouse-routing-changes`
  — narrow to "no engine-physics-authoritative combat", 3D becomes the presentation direction.
- **Mobile-compat second target** (`CLAUDE.md`, High Level Spec): dropped 2026-06-12; needs routing.
- **Stack ADR** (`docs/adrs/2026-06-06-build-stack-decision.md`): was provisional pending a
  confirmation spike — KM-DIRECTOR-SPIKE **absorbs/supersedes**
  `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md`. Do not run both; reconcile when
  the spike is specced as a slice.
- **Wishlist/journeys**: spectacle framing of the watch step feeds the next wishlist revision.

Also note: this direction work does **not** decide the backpack-vs-dual-layer comparison this
branch exists to run (`Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md`
still wants its ADR; the comparator feel-test happened but no verdict was recorded).

---

## 5. Environment facts the executor needs

- **Godot 4.6.3 is installed and on PATH** as `godot` (`C:\Users\Yanjie\.local\bin\godot`).
- The existing `godot_spike/` project is the **deploy slice on GL Compatibility** — it cannot do
  volumetric fog/SDFGI. **Do not touch it.** The plan creates a fresh `godot_director_spike/`
  on Forward+.
- Headless test pattern (matches existing repo convention):
  `godot --headless --path godot_director_spike --script res://tests/director_check.gd`.
- Movie capture for the judging artifact: `godot --path godot_director_spike --write-movie tmp/money-shot.avi`.
- Owner's global rules: **no commits without explicit instruction** (plan execution approval counts
  once the owner picks an execution mode), **no Claude co-author trailers**, test reports in
  chronological point form per the owner's global CLAUDE.md.

---

## 6. How to resume

1. Read the design spec, then the plan (paths in §2). The plan is self-contained: complete code
   per step, TDD for the pure logic (log loader, shot-list builder), observation checkpoints for
   visuals, 9 tasks ending in FPS instrumentation + movie capture + `VERDICT.md` template.
2. Ask the owner to choose an execution mode (this was the exact pause point):
   **subagent-driven** (`superpowers:subagent-driven-development`, fresh subagent per task) or
   **inline** (`superpowers:executing-plans`). Then execute.
3. After execution: iterate on *feel* (camera constants in `director.gd`, VFX scale in
   `garnish.gd`) before convening judges — criteria are not renegotiable, feel tuning is expected.
4. Fill `godot_director_spike/VERDICT.md` with the judges; route the outcome per §4.

Open design threads deliberately deferred: the emotional layer (enemy/war-front radio chatter
reacting to your machine — fits the "feared ace" fantasy; barks/portraits cheap, voice later),
escalation of the director grammar beyond the spike's six shot modes, and how coarse space enters
the real sim (the spike's `data/event-contract.md` deliverable is the design input for that).
