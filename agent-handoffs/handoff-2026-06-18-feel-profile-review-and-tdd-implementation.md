# Handoff — FeelProfile: Codex review fold-in + first TDD implementation

This picks up from the combat-feel **data-spine design pass** (build → sim → log → choreographer →
director), which closed with the combat-choreographer commit `ac16c21`. Today added the fifth and
final link of that spine as a design, hardened it against an adversarial review, and turned it into
the first real GDScript of the spine. Branch: `combat-feel-restart`.

## What landed

**1. FeelProfile design spec — committed (`2462b81`).**
`docs/superpowers/specs/2026-06-18-feel-profile-design.md`. The per-build *presentation lean*: a pure
function of a build's resolved stats → a per-mech bias bundle `{heft, tempo, mode_mix}` that makes a
heavy bruiser read heavy and a nimble gunner read nimble, **without** rewriting the Director Grammar
or Choreographer. Deterministic, cosmetic, never combat truth, never in the log, never read by the
sim. It supplies a bias; consumers apply it on top of their own params.

**2. Codex adversarial review, folded in.** Ran `codex exec --sandbox read-only` against
`.codex-review-prompt.txt`; the full review is saved at `.codex-feelprofile-review.md` (untracked —
keep or discard as you like). Verdict: design directionally sound, **no over-engineering flags** — the
opposite, it wanted three small tightenings. Accepted findings folded into the spec (the commit above
is the post-review revision):

- **Log-boundary analogy corrected** — FeelProfile is cosmetic *like* `motif`/`tier`, but *unlike*
  them is never serialized in the truth layer at all (they ride the log and are merely excluded from
  verification).
- **Input seam pinned** — the spec now names the minimal `ResolvedBuildFeelStats` view it needs from
  `resolve(build)` (total weight, armor, per-weapon `cooldown` / resolved expected `damage` /
  `feel_mode_weights`), so the implementer never has to infer feel from motif strings or the log.
- **`mode_mix` kept genuinely open** — derivation now **aggregates each weapon's own
  `feel_mode_weights` map** instead of switch-matching weapon classes; class names demoted to
  authoring guidance.
- **Empty / zero-damage build fallback pinned** — `tempo = 0`, `mode_mix` = uniform `1/3` each.
- **"damage share" = pre-sim resolved damage, not fight-log damage** (log omits misses → would make
  the profile outcome-derived).
- **Consumer-side cadence clamps required** — `heft` and `tempo` push the same params in opposite
  directions, so each consumer clamps the blended result to readable min/max.

Finding #6 (evasion ownership) needed no change — current framing is the safe one.

**3. FeelProfile implemented via TDD — UNCOMMITTED.** Two new files, an isolated leaf unit; nothing
else references it, no regression surface.

- `godot_director_spike/scripts/sim/feel_profile.gd` — pure static `derive(build) -> {heft, tempo,
  mode_mix}`. `heft` = normalized `total_weight + armor`; `tempo` = normalized damage-weighted mean of
  `1/cooldown`; `mode_mix` = damage-share-weighted aggregate of per-weapon mode maps, normalized to
  sum 1, with the uniform fallback. Normalization constants (`HEFT_REF_MAX = 300`, `TEMPO_REF_MAX =
  3.0`) are **explicit placeholders** — the spec defers magnitudes to look-lock tuning; only the
  monotonic ordering and `[0,1]` bounds are contractual.
- `godot_director_spike/tests/feel_profile_check.gd` — 16 checks. RED was witnessed first (load FAIL,
  exit 1, feature missing), then GREEN (`---- ALL PASS`, exit 0). Covers: shape, bounds, determinism,
  monotonicity (heavier ⇒ ≥ `heft`; faster ⇒ ≥ `tempo`; +melee ⇒ ≥ melee weight), axis independence
  (heavy build can still be high-tempo), empty + zero-damage fallbacks, and outcome-independence
  (extra `winner`/`hp_remaining` keys leave the profile byte-identical).

Run it: from `godot_director_spike/`,
`~/.local/bin/godot --headless --script res://tests/feel_profile_check.gd`.

## Honest status — can we demo the intended effect today? **No.**

Verified in the running code (`grep` for `heft`/`tempo`/`mode_mix`/`framing_emphasis`/`cut_cadence`):
**`feel_profile.gd` is the only file that references the feel axes.** It is a correct leaf with
nothing wired on either side. For the cinematic payoff (a build *looking like itself* on screen),
three things must land and FeelProfile is only the first:

1. **Producer** — `resolve(build)` emitting `ResolvedBuildFeelStats`. That's the M1 backpack system,
   not built. Today the input must be a hand-fed fixture dict (which is exactly what the test does).
2. **Consumers** — the Director Grammar and Choreographer reading the axes and biasing their own
   params. **Both are design-only specs right now — no code.** No `framing_emphasis`/`cut_cadence`
   hooks and no choreographer exist in `scripts/`. The bias currently flows into nothing.
3. **Viewer** — the proven hybrid director films *hand-authored* fight logs; it neither computes nor
   applies a FeelProfile.

**What is honestly demoable today:** the derivation in isolation — feed two contrasting fixture
builds and show the axes move in the intended directions (bruiser → high `heft`, low `tempo`,
`melee`-leaning; skirmisher → low `heft`, high `tempo`, `barrage`-leaning). That truthfully shows
"a build's mechanical character is computable," but it is **not** the on-screen "looks like itself"
effect, which needs the consumers implemented.

## Suggested next steps

- **If the goal is the visible effect:** implement a consumer. The Choreographer (build → spawn
  positions + movement cadence) is the more self-contained of the two and is fully designed
  (`docs/superpowers/specs/2026-06-17-combat-choreographer-design.md`). Wiring `heft`/`tempo` into its
  `STRIDE`/boost/ring-radius params is the shortest path to seeing the lean on screen — but it depends
  on the choreographer itself being built first.
- **If staying honest about scope:** the FeelProfile leaf is done and tested; rest it and either build
  the producer (M1 backpack `resolve(build)`, the actual active v0.1 slice per CLAUDE.md) or write the
  implementation plan that sequences sim → log → choreographer → director → feel into a deliberate
  build order.
- A two-build fixture demo script (print both profiles side by side) is a quick, truthful artifact if
  you want to *show* the derivation responding before any consumer exists.

## State of the tree

- Committed on `combat-feel-restart`: the FeelProfile design spec (`2462b81`).
- **Uncommitted:** `scripts/sim/feel_profile.gd` + `tests/feel_profile_check.gd` (the implementation),
  ready for review. No `.uid` sidecars were generated — `--headless --script` skips the import pass;
  open the project in the editor once to generate `feel_profile.gd.uid` + `feel_profile_check.gd.uid`
  to match repo convention before committing.
- Untracked review scratch: `.codex-review-prompt.txt`, `.codex-feelprofile-review.md`.
- Per project rule, nothing was committed beyond the spec the owner explicitly asked to commit.
