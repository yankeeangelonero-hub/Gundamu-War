# Director Grammar — Phase 3, Slice 1: Time-Emphasis Arbiter + Impact Frames

> Status: PROPOSED plan, 2026-06-16. Awaiting owner go-ahead before execution.
> Design: `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (Timing/Cut §, Open Q#3).
> Builds on shipped Phase 1 (ShotGrammar) + Phase 2 (Grade). Determinism gate: golden hash 2543717900.

## Goal
The spec (Timing/Cut, F37/F14/F38) calls for the three time-emphasis tools — **bullet-time**,
**hold-on-impact (hitstop)**, and **impact-frames** — to go through a **precedence arbiter** so
"one tool owns a given beat" and they don't stack into mush. Two of the three exist; impact-frames
(F37) is new and the precedence is currently informal. This slice formalizes the precedence and adds
impact-frames, lifting the time parameters into the grammar (continuing the parameters-out pattern).

## What exists today (grounded in the code, not assumed)
- **bullet-time**: the director sets `Engine.time_scale = shots[_shot_idx].time_scale` per shot
  (`director.gd:203`); bullet-time shots carry `bt_scale` (~0.07). The grammar already holds
  `bt_pre/bt_post/bt_scale`.
- **hold-on-impact (hitstop)**: `garnish._hitstop(dur=0.07)` sets `Engine.time_scale = 0.05` briefly,
  but **already guards** `if Engine.time_scale < 0.2: return` (yields to bullet-time / another
  hitstop) and restores to `director.current_time_scale()` (never leaves time stuck). The `dur` is
  a hardcoded literal.
- **impact-frames (F37)**: does not exist.

So the informal precedence today is **bullet-time > hitstop** (via the `<0.2` guard). This slice
makes it a real 3-way owner and adds the third tool.

## Design decisions (the spec's Open Q#3, resolved)

**Precedence = an escalation ladder by beat weight (one tool owns the beat, by construction):**
1. **bullet-time** — when a bullet-time shot is active (`Engine.time_scale` already < ~0.2 from the
   shot list, i.e. the kill cam), it OWNS the beat. Hitstop and impact-frames are suppressed (the
   kill is already in slow-mo; a freeze or flash on top is mush).
2. **hold-on-impact (hitstop)** — a brief freeze on a **significant** hit (damage > the existing
   hitstop threshold), only when not in bullet-time.
3. **impact-frames** — a sub-perceptual 1–2 frame contrast/flash on a **minor** contact (damage **at
   or below** the hitstop threshold), only when not in bullet-time.

The key design point: hitstop and impact-frames partition the hit space by weight (heavy → freeze,
light → flash), so they are mutually exclusive *by construction* rather than by a suppression race —
every contact gets emphasis scaled to its weight, and bullet-time overrides both during the kill.
This is a clean escalation ladder: minor hit → flash, heavy hit → freeze, kill → slow-mo.

**Approach — minimal, not a heavy abstraction (per project code-style):** keep the precedence logic
in ONE small owner rather than a new arbiter class graph. The cleanest home is a tiny
`TimeEmphasis` helper (or a few functions on the existing director) that:
- owns the single write to `Engine.time_scale` for *transient* effects (hitstop), keeping the
  director's per-shot write as the baseline it restores to;
- exposes `request_hitstop()` and `request_impact_frame()` that apply the precedence guards;
- the impact-frame visual (a 1–2 frame additive contrast/flash) is a brief CanvasLayer/ColorRect
  pulse or a one-tick Grade adjustment bump — NOT a new render pipeline.

This absorbs the existing `_hitstop` guard rather than duplicating it, and adds impact-frames behind
the same precedence gate.

**Grammar parameters lifted (Timing block):** `hitstop_dur` (default 0.07, from the current literal),
`impact_frame_len` (default ~2 frames), `impact_frame_strength` (the contrast/flash magnitude). The
existing `bt_pre/bt_post/bt_scale` stay. All defaults reproduce today's behavior (impact-frames off
by default until tuned, OR a subtle default — owner call below).

## Open owner decision (need a call before/at execution)
- **Impact-frame default strength:** ship it subtle-on by default (minor contacts get a faint 1–2
  frame flash) so the behavior is visible for review and then tuned, or default OFF (param at 0,
  enabled only after a tuning pass? *Recommendation: subtle-on by default, then tune from the
  capture.* (The "which beats" question is resolved by the escalation ladder above: minor hits ≤
  threshold get the flash, heavy hits get the freeze.)

## Files (anticipated)
- **Modify** `shot_grammar.gd` — add `hitstop_dur`, `impact_frame_len`, `impact_frame_strength` to
  the Timing block (+ assert defaults in `shot_grammar_check.gd`).
- **Modify** `director.gd` and/or a small new `scripts/director/time_emphasis.gd` — the precedence
  owner: transient `Engine.time_scale` writes + impact-frame trigger, with the 3-way guard.
- **Modify** `garnish.gd` — route `_hitstop` through the arbiter (absorb its existing guard); add the
  impact-frame request on the contact path.
- **Create** `tests/time_emphasis_check.gd` — the unit test the spec names: "given overlapping beats,
  exactly one tool owns the beat" (bullet-time suppresses hitstop + impact-frame; hitstop suppresses
  impact-frame; impact-frame runs alone on an unclaimed contact).
- Determinism guard: `hybrid_check.gd` hash MUST stay `2543717900` (time-emphasis is render/feel, not
  the shot-list solve).

## Verification
- Headless: `time_emphasis_check.gd` (precedence), `shot_grammar_check.gd` (new params),
  `hybrid_check.gd` (hash unchanged), boot smoke.
- Visual (owner-gated windowed run): a `--frames` capture showing an impact-frame on a normal hit, a
  hitstop on a heavy hit, and the bullet-time kill — confirming exactly one fires per beat and they
  read distinctly.

## Execution method
Subagent-driven (implementer → spec review → quality review per task), same as Phase 2, with the
no-branch-changing-git + headless-only + import-on-unknown-class guardrails.
