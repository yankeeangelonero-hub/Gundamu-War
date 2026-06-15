# Handoff — Director Grammar work, resume 2026-06-17

This picks up a long session on 2026-06-16. The short version: we rebooted v0.1 onto a clean
branch, built a three-document research foundation for combat/camera feel, designed a first-class
"Director Grammar" system from it, wrote a Phase 1 implementation plan, and got Phase 1 mostly
built and reviewed. It stopped mid-way through the last review fix. Everything below is where to
pick up.

## Where the project is

All work is on the branch `combat-feel-restart`, which was cut from commit `3a6e652` — the proven
3D combat viewer as it stood BEFORE the M1/M0 backpack build-editor work that the owner judged had
broken the combat feel. `main` (origin/main, cb4a7b3) is untouched and holds that build-editor
experiment as an archive to cherry-pick from later; it is not the active line. Do combat-feel work
on `combat-feel-restart`. See the memory `combat-feel-restart` for the why. The branch is local
only — it has not been pushed, per the no-push-without-instruction rule.

Two combat changes shipped early in the session and are committed (9c9000e): the
`fight_log_everything` fight was rebalanced to feature the full arsenal (missiles and cannon now
read throughout, not just beams/gatling), and the bullet-time kill-cam was fixed so it holds
through the actual explosion instead of cutting away before the kill. The fix moved `BT_POST`
0.35→0.55 and pulled the `destroyed` event from tick 235→231.

## The research foundation (read these first for any combat/camera work)

There are now three combat-feel seeding documents, all committed and elevated in CLAUDE.md's Key
Documents table and marked with in-file SEEDING DOCUMENT banners. They are the canon; camera work
makes or breaks this game, so they guide all of it. Findings are numbered F1–F40 and the design
spec tags every parameter back to them.

- `Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md` — F1–F10. The
  original pass: the camera grammar is on-target, the gap is the movement model.
- `Research/Research Documents/research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md`
  — F11–F21. Cadence-as-weight, exchange variety, the cockpit lens, across UC/0083/08th/Evangelion.
- `Research/Research Documents/research-synthesis-2026-06-16-director-grammar-lighting-color-lens-continuity.md`
  — F22–F40. Lighting, color/grade, lens, spatial continuity — the director-grammar dimensions the
  first two passes missed.

Both later passes were run with the deep-research workflow but synthesized by hand, because the
workflow's auto-synthesis step failed/was-stopped each time; the verified-claim sets survived and
were merged manually. Note the standing rule recorded in the memory `research-model-rule`: all
future research tasks run on Sonnet or Haiku, never Opus, unless the owner says otherwise — the
all-Opus deep-research runs were burning ~3.7M tokens each. To enforce it, edit the persisted
deep-research workflow script to add `model: 'sonnet'`/`'haiku'` to the agent() calls before
launching.

## The design we settled on

The vision: builds should eventually drive feel — a heavy-cannon mech reads slow and deliberate, a
light-missile mech reads agile and swarmy. We split this into two layers and scoped them as separate
specs.

The Director Grammar is the first-class, global spectacle layer — every cinematic-director dimension
(composition, lens, lighting, color, continuity, cut/timing, spectacle staging) lifted into one
tunable, F-tagged `ShotGrammar` resource, with the shot math left in the director. It is the same
for every fight. The FeelProfile (a later, separate spec — not yet written) sits on top and only
modulates emphasis per build; it does not own any grammar values. Scope decisions the owner made:
the cockpit feedback/bond system is omitted from v0.1 (deferred to v0.2 pilot-fit), but a
`cockpit_pov` shot that looks outward at the enemy IS in scope as a camera primitive. Movement
(F1-F3, F11-F13) belongs to the FeelProfile/mech_actor, not the grammar.

The design spec is `docs/superpowers/specs/2026-06-16-director-grammar-design.md`. It was reviewed
three ways (Codex + Gemini + Claude via /octo:review) for fidelity to the research — verdict high
fidelity, no wrong F-tags, all refuted claims honored — and then revised to close the gaps the
review found (the biggest was that the cockpit_pov shot had been orphaned between specs; it is now
in the Composition shot vocabulary). The spec's build sequence is four phases: (1) ShotGrammar
extraction + parity, (2) the Grade node for lighting/color, (3) new behaviors (compression, impact
frames + a time-emphasis arbiter, staggered blast, yield-by-class, cockpit_pov, frame_and_streak,
melee framing), (4) soft continuity constraints. Each phase gets its own plan.

## Phase 1 implementation status

The Phase 1 plan is `docs/superpowers/plans/2026-06-16-director-grammar-phase1-shotgrammar-extraction.md`.
It is a parity-safe refactor: lift hybrid.gd's hardcoded camera/timing numbers into the ShotGrammar
resource at current-value defaults, proven byte-identical by a frozen golden shot-list hash. It was
executed with subagent-driven development (fresh implementer per unit, then a spec-compliance review
and a code-quality review each).

Committed and reviewed (both reviews passed):
- `eaf6a8d` + `4b0eb70` — Task 1: the `ShotGrammar` resource
  (`godot_director_spike/scripts/director/shot_grammar.gd`, note the singular `director/`, distinct
  from the existing plural `directors/`) with `class_name ShotGrammar`, `@export` fields for Timing
  and Composition/framing, and a static `default()`. Its test is `tests/shot_grammar_check.gd`
  (21/21 pass).
- `2924154` — Task 2: the golden parity snapshot in `tests/hybrid_check.gd`
  (`GOLDEN_SHOTLIST_HASH := 2543717900`).
- `897ae00` — Task 3: `build_shot_list(events, dur, grammar := null)` reads Timing from the grammar.
- `e79919c` — Task 4: the runtime camera reads Composition/framing from a `_grammar` instance member;
  the six dead consts (OS_LEN, CUT_LEN, BT_PRE, BT_POST, BT_SCALE, ISO_OFFSET) were deleted.

Both check scripts are green: `hybrid_check.gd` 16/16, `shot_grammar_check.gd` 21/21. The parity
snapshot proves the shot list is byte-identical to pre-refactor.

## Uncommitted working-tree state to resolve first thing

The session stopped while committing the last review fix, so the tree is dirty:
- `godot_director_spike/tests/hybrid_check.gd` has the C1 + C4 review fix applied but NOT committed:
  a null-guard on `Hybrid` in `_check_hybrid_parity_snapshot()` (mirroring the sibling check) and an
  expanded doc comment on `GOLDEN_SHOTLIST_HASH` (the value 2543717900 is unchanged). This is good;
  commit it.
- Untracked `.uid` sidecars: `scripts/director/shot_grammar.gd.uid` and
  `tests/shot_grammar_check.gd.uid`. Godot 4 generates these; they should be committed alongside
  their scripts.
- Modified `.fbx.import` files under `godot_director_spike/models/` — regenerated by a
  `godot --headless --import` pass that was needed for Godot to register the new `class_name
  ShotGrammar` (a brand-new script needs an import pass before the engine sees it). Decide whether to
  commit this metadata churn or `git checkout` it; it is incidental to the refactor.
- The pre-existing modified `Research/Gundam Reference/gundam mk2 for sale.glb` is unrelated and has
  been carried, uncommitted, all session.

## How to resume

1. Resolve the dirty tree above: commit the C1+C4 fix to `hybrid_check.gd` plus the two `.uid`
   sidecars; decide on the `.fbx.import` churn. A deferred-notes section was meant to be appended to
   the Phase 1 plan in the same commit but was not written — add it (content below) or skip it, your
   call.
2. Run Phase 1 Tasks 5 and 6 (verification, no new code): capture a `--still` of the hybrid fight and
   eyeball it for visual parity (the F40 look-lock), then run the full check suite
   (`shot_grammar_check.gd`, `hybrid_check.gd`, `director_check.gd`) and confirm `main.gd` still
   launches a live fight. Commands are in the plan.
3. Dispatch a final whole-implementation code review, then use the finishing-a-development-branch
   skill to decide how Phase 1 integrates.
4. Then write the Phase 2 plan (the Grade node: chromatic fill F22, turn the disabled garnish
   beam-lights back on for F24, mood variants F26/F27). Phases 3 and 4 follow.

Test invocation pattern (Bash tool, this machine): the Godot binary is `~/.local/bin/godot.cmd`
(Godot 4.6.3). Headless checks run as
`~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/<name>.gd` — they
print PASS/FAIL lines and exit 0 or 1. Resource-leak / RID warnings on shutdown are harmless noise;
judge by the PASS/FAIL lines and the exit code. A brand-new GDScript file may need a
`godot --headless --import` pass before the engine registers its `class_name`.

## Deferred seams surfaced by the Phase 1 code review (carry into later phases)

These are real but were correctly out of Phase 1 scope — they only bite once a custom grammar or a
new shot mode exists, and Phase 1 always uses `ShotGrammar.default()`, so they cannot trigger yet.

- Grammar wiring seam (Phase 3): `build_shot_list` takes a `grammar` param (static) while
  `_update_camera` reads the `_grammar` instance member. Consistent at defaults today, but a caller
  passing a custom grammar must set BOTH. When the FeelProfile/custom-grammar wiring lands, give the
  director one grammar source and document/enforce it.
- Framing key safety (Phase 2): `_grammar.framing[s.mode]` has no `.has()` guard; a missing or
  misspelled key (or a new VOCAB mode without a framing entry) returns null and crashes on the next
  property read. Add a guard or typed per-mode structs when the framing table is authored beyond
  defaults.
- melee_cut timing not extracted (Phase 3): the `melee_cut` shot's `t0/t1` (mt-0.5, mt+1.7) and
  `time_scale` (0.5) are still inline in `build_shot_list`, an untunable island versus the
  grammar-driven Timing. Extract when melee framing is tuned. Also: a non-lethal melee event in a log
  would add a second time-dilated shot, which the `hybrid_check.gd` "exactly one shot dilates time"
  assertion does not expect — revisit that assertion then.

## Other running threads, in case they matter

There may still be open Godot windows from the session (the build screen, the deploy slice, the
hybrid fight viewer) and a now-redundant git worktree at `D:\claude\GW-3a6e652` that was used to run
the pre-build-editor viewer before the branch existed — it can be removed with `git worktree remove`
once nothing is running from it. `.firecrawl/` is gitignored. The web prototype under `prototype/`
and the older 2D Godot deploy slice under `godot_spike/` are both intact references, not the active
line.
