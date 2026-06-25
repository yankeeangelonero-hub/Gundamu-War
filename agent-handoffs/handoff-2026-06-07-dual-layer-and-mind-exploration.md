# Handoff — Dual-layer pivot + mind-authoring exploration (2026-06-07)

Pause point after a long design session. This captures **what is recorded (canonical)**, **what is
trial-only (prototype, not in docs)**, the **open questions**, and the **next steps**. Read this
first when resuming.

---

## 1. The one-paragraph state

The game was **redefined** this session from the pilot-fit/sync direction to a **dual-layer**
build-fighter: the player is the engineer and authors a **body** (kitbash under a weight/power
budget) **and** a **mind** (the pilot's combat AI), then watches a deterministic duel; alignment
between body and mind is read from the fight + a debrief (no sync meter); depth is fair/horizontal;
attachment is to the creation. That pivot is **fully recorded** in the Vouse docs and the first
slice (the deck run-model decision) is **closed**. After that, we **explored the mind-authoring
surface in the throwaway web prototype only** — a Slay-the-Spire-style deck (energy, block,
draw/discard, rarity copy-limits) and then FFXII-style **gambits** — none of which is recorded yet,
and some of which **contradicts the closed decision**. We paused mid-discussion of "how to design
the AI."

---

## 2. Canonical (recorded in the Vouse docs — trust these)

| Artefact | Path | Status |
|---|---|---|
| Wishlist r3 (dual-layer) | `Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md` | frozen |
| Core-loop flow | `Research/flows/dual-layer-core-loop.md` | frozen |
| User journey D1 | `Research/User Journeys.md` (Journeys 1–13 superseded) | active |
| High Level Spec | `High Level Project Specifications.md` | reconciled |
| User Story US-001 | `User Stories/US-001.md` | **approved** |
| Roadmap v1.0.0 | `Roadmap.md` (M0 spike · M1 essential slice *in-progress* · M2 full loop) | active |
| Version 0.4 | `Project Version/Version 0.4/Version 0_4 Project Specifications.md` | open |
| Slice v0.4-slice-01 (deck-run-model) | `Project Version/Version 0.4/Slices/…` | **done** |
| Decision ADR | `Research/Research Documents/adr-2026-06-07-deck-run-model.md` | frozen |

**High Level Spec changes:** added **FEAT-008** (behaviour deck = the mind), **FEAT-009**
(alignment readout + debrief, no sync meter), **FEAT-010** (fair horizontal depth), **ARC-006**
(restricted deterministic behaviour language for PvP re-sim). Superseded: **FEAT-002** (fit/sync),
**FEAT-003** (positive-valence growth), **FEAT-005** (deploy gamble), **BEH-003** (positive
valence). Reframed: **FEAT-004** → body-gates-the-mind; **BEH-004/005** → alignment legibility /
dead-card. Added a Permanent Decisions entry + Vocabulary.

**US-001 falsifiable claims (the spine future slices must hold):** (1) same `{body, deck, opponent,
seed}` → byte-identical fight; (2) a body-incompatible behaviour is **dead** and never fires;
(3) the duel outcome is **never** shown without a concrete in-fight reason (dead card / whiff /
hesitation) — never "luck".

**Slice v0.4-slice-01 decision (frozen ADR): the run model is `construction`** — the whole live
deck is the pilot's always-available repertoire, played by deck-order priority; **no draw, no
per-fight RNG.** Chosen by playtest evidence (the naive draw model was degenerate; construction is
faithful + legible + luck-free). This is the runtime contract the combat-core slice was meant to
implement.

**docs/ tree** (old pilot-fit record) is superseded with banners; project `CLAUDE.md` has a
direction-changed banner (its body still needs a full rewrite via `vouse-routing-changes`).

**Validators (last run): green** — voice lint clean; roadmap valid (0 advisory); migration clean;
citations clean **except 23 pre-existing failures** in the superseded `Project Version/Version 0.2`
and `0.3` specs (stale BEH/ARC refs — untouched, follow-up cleanup).

---

## 3. Trial only (prototype — NOT recorded, and partly CONTRADICTS the ADR)

After closing the slice on `construction`, we kept exploring the mind surface **in the prototype
only**. None of this is in the docs. **If any of it is adopted, it must supersede the construction
ADR via `vouse-routing-changes` and update the wishlist + High Level Spec.**

Prototype files (throwaway, web; single source of truth shared by browser + headless):
- `experiments/dual-layer-deck-combat.html` — the harness (UI).
- `experiments/dual-layer/sim.js` — the shared deterministic combat core.
- `experiments/dual-layer/runmode-check.cjs` — headless determinism + comparison check.
- Slice evidence: `Project Version/Version 0.4/Slices/Unit Tests/evidence/` (the *original*
  construction/draw/hybrid run — see the wrinkle in §6).

What was added to the prototype beyond the ADR (all deterministic, all AI-played / watch-only):
- **`round` mode** — Slay-the-Spire rhythm: each round refill energy (3) + draw a hand (5) + play
  several cards. Verified deterministic; **no stalling** (unlike naive draw).
- **"Bite" pass** — scarce energy, pricier strikes, a **Beam Burst** nuke (cost 3), and **Block**
  that **accrues within a round and resets next round** (turtle-vs-all-in spend choice). This is
  what made `round` finally feel different from `construction` (round can bank ⛊38 block; construction
  caps ~⛊12).
- **Draw/discard** — bigger decks, hand is a real subset, played cards discard + reshuffle; **no
  hand-lock**. Reintroduces genuine **draw luck** (the thing construction avoided).
- **Rarity copy-limits** — duplicates allowed; common ×3 / uncommon ×2 / rare ×1; deck cap 12.
  Framed as a deckbuilding *cost*, not a power tier (everyone can run the cap → stays fair).

**Tension to remember:** the ADR chose construction *because* it is luck-free and faithful; the
draw/discard work brings luck back. These pull against each other. The recurring owner instinct all
session was toward **deterministic, authored intent** (which is why construction won, and why
gambits below are attractive).

---

## 4. The mind-authoring discussion (talked through, nothing built)

The session then re-opened the *mind* surface and landed on two big ideas, discussed only:

**A. The deck engine is already a gambit engine.** Every "card" is `when(condition) → do(action)`
played by priority — that *is* FFXII gambits. The deck/energy/draw/rarity layer is scaffolding on
top. So "designing the gambit system" is mostly: let the player **compose conditions + actions
directly in priority order**, and drop the draw scaffolding → back to **deterministic authored
intent** (construction's faithfulness, richer surface).

**B. "How do you design the AI?" → there are FOUR AI roles, usually conflated:**
1. **Substrate** — one deterministic decision engine running *every* mind (player's and foes').
2. **Player's authored mind** — the dev builds the *tools* (gambit vocabulary), not the AI.
3. **Shipped default mind** — the competent baseline a casual gets untouched (the real "dev AI").
4. **Opponent population** — near-term hand-authored archetype ghosts (rusher/turtle/kiter/baiter)
   as a teaching ladder; endgame real players' stored minds.
The human's role = **author + spectator** (a Carnage Heart / Gladiabots programmer-game), not an
action game.

---

## 5. Open questions (unresolved — pick up here)

1. **Mind surface: deck vs gambits vs hybrid.** Leaning gambits (deterministic, legible, the
   recurring preference; engine already supports it). Deciding this likely **supersedes the
   construction ADR** (gambits *are* construction with a richer surface).
2. **Adopt round/energy/block/draw/rarity?** If yes → supersede the ADR + update wishlist/spec.
3. **Anti-convergence** (stop one "solved" gambit/deck list from killing the PvP meta): imperfect
   info, limited slots, RPS between specialists, body-coupling, **variety from the opponent
   population rather than in-fight RNG**. (This was an open project question from the very start.)
4. **Reactive gambits / reading enemy intent** (counter the wind-up, bait the counter) → AI-vs-AI
   mind-games. The elevating depth; needs a telegraph/wind-up system.
5. **Spectator agency** — pure author-and-watch, or one live in-fight lever (override / tactic
   call)? Recurring lurking fork.
6. **PvP power-fairness model** — horizontal vs bracketed vs compressed (still open from the
   wishlist).
7. **Opponent teaching ladder + default mind + onboarding ramp** — undesigned.
8. **Biggest:** is "human authors an AI and watches" the right core at all? (Owner raised it; not
   resolved.)

---

## 6. Known wrinkles / housekeeping

- **Slice evidence vs evolved engine.** `runmode-check.cjs` is the slice's verification tool and
  imports `sim.js`. After the slice closed, `sim.js` was evolved (bite/draw/rarity). The slice's
  evidence file (`…/evidence/runmode-comparison.md`) is the **pre-bite snapshot** and matches the
  Unit Test Record. **Do not blindly re-run `runmode-check.cjs`** against the current `sim.js` — it
  would overwrite the evidence with rebalanced numbers and break that consistency. If you keep
  iterating the engine, snapshot the `sim.js` the slice was verified against, or treat the evidence
  as historical.
- **Local server still running** on the Tailscale interface: `100.65.78.100:8799`
  (`http://desktop-boc7tdq.tail627b0d.ts.net:8799/experiments/dual-layer-deck-combat.html`).
  Background task id `bmas52azd`. Stop with: `Get-NetTCPConnection -LocalPort 8799 -State Listen |
  %{ Stop-Process -Id $_.OwningProcess -Force }`. A firewall rule for 8799 was **not** added
  (auto-denied); remote tailnet devices need: `New-NetFirewallRule -DisplayName "kx-harness-8799"
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8799 -RemoteAddress 100.64.0.0/10`.
- **No git commit** was made this session (per repo rule).
- **Leftover doc debt:** project `CLAUDE.md` + `Readme.md` full rewrite (via
  `vouse-routing-changes`); the 23 stale V0.2/V0.3 citations; the old `docs/` strays
  (`homecoming.mmd`, `docs/slices/KM-DEPLOY-*`, `docs/adrs/*`) are bannered-by-context but not
  individually superseded.

---

## 7. Recommended next move on resume

1. **Decide the mind surface** (deck vs gambits). Recommendation: prototype a **Gambit Bench** in
   the harness (the engine already supports `when→do` by priority) and feel it vs the deck.
2. If gambits (or round/block/draw) win → **route through `vouse-routing-changes`** to supersede the
   construction ADR and fold the chosen mechanics into the wishlist + High Level Spec, then
   re-baseline Version 0.4 / US-001.
3. Then the committed buildable path for M1 (the dual-layer essential slice realising US-001) is:
   **KM-BODY** (kitbash + weight/power budget) → **KM-MIND** (the chosen authoring surface) →
   **KM-DUEL** (deterministic duel + debrief). Build via `vouse-slice-lifecycle`.
4. In parallel, the **M0 Godot stack spike** is still pending and is the prerequisite for the real
   (non-web) build.

Everything substantive from this session is either in the canonical docs (§2) or the prototype
(§3); this handoff is the bridge between them.
