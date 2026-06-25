---
project: kitbash-mecha
repo: gundamu-war
artefact: research-document
doc_type: wishlist
kind: wishlist
status: frozen
created: 2026-06-07
confirmed: 2026-06-07
supersedes: docs/wishlist/wishlist.md
supersedes_note: >
  Supersedes the pilot-fit / war-front wishlist (docs/wishlist/wishlist.md, r2, 2026-06-06)
  on the game's core. Also supersedes the long-stale Research/wishlist.md (the original
  "Mech Bags" backpack-grid v0.1 deferred-items list). Prior documents stay readable.
---

# Wishlist Revision 2026-06-07 — The Dual-Layer Direction (r3)

Authored from a design-grill session on 2026-06-07. Per the wishlist convention the prior
documents stay readable; this one states what now holds. **Confirmed by the owner 2026-06-07 —
this wishlist is frozen.** The `docs/` design record and the work map still describe r2 and must be
reconciled to this direction separately (a `vouse-managing-versions` / `vouse-project-docs`
job, not this one).

## What changed, in one line

The game is no longer "raise and bond with an ace pilot." It is **author a war machine's body
*and* its mind, then watch your design fight.** The differentiator is the dual layer and the
alignment between its halves.

## What this is

Kitbash Mecha is a dual-layer mech build-fighter. The player is the engineer, never the pilot.
You author two things:

- **The Machine — the body, the product.** You kitbash a humanoid mech from snap-together parts
  on a frame, under an Armored-Core-style weight and power budget. The body decides what the
  machine *can* do — reach, weapons, mobility, armour — and its silhouette. This is tactile
  craft: the satisfying act of building a thing with your hands.
- **The Pilot — the mind, the AI.** You author how the machine fights as a **behaviour deck** —
  cards that each carry a trigger ("when enemy in reach"), an action ("heavy saber strike"), a
  cost, and synergies. The pilot is the *face* of that deck — a callsign and a presence — but
  mechanically she is the program you wrote. The deck decides *how* the body's capabilities are
  actually used.

The game is the **interplay**: the strongest aces are those whose body and mind are in
alignment. A saber body with an aggressive close-range deck is devastating; the same body told
to keep its distance is useless — it never draws its blade. You build both halves and hand them
to the war.

## Alignment is the fight, not a meter

There is no sync gauge or fit number. The **watched duel itself is the readout.** When body and
mind disagree you *see* it: a melee mech that won't close visibly flails, its best cards dead.
When they agree, you see her cook. A post-fight **debrief narrates the misses** — which cards
never fired, which whiffed out of range, where she hesitated — so the cause is always legible
and never reads as luck. (This replaces r2's "sync climbing toward a breakthrough.")

## The body gates the mind

The two layers interlock mechanically: the machine determines the vocabulary the pilot can even
think in. A "Saber Rush" behaviour exists only if you built sabers; "Hold the Line" needs a
shield. Alignment is therefore structural, not hoped-for — you cannot give her a thought her
body cannot perform. (This generalises the earlier skill↔part gating idea.)

## Fair, horizontal depth — invention, not grind

The fun is inventing new builds, and it must stay fair to new players — load-bearing, because
the endgame is competitive. So:

- **Sidegrades, not upgrades.** Parts and cards are *different*, not *better*. No rarity tiers,
  no god-rolls. A newcomer holds the same toolkit; the veteran's edge is knowledge.
- **Depth from combination.** The skill ceiling is which body + deck answers which — a living
  rock-paper-scissors where a clever new build beats a stale strong one.
- **Growth is wider, not bigger.** Fights unlock new parts and cards — more to invent with —
  never larger numbers. Salvage hands you new *options*, never better stats.

## Attachment is to the creation

The emotional pull is **pride and mastery**, not caretaking. You are attached to what you made —
a feared, recognisable signature ace (a silhouette plus a playstyle) whose name the front knows.
The pilot is a runtime with a persona; the warmth is "look what I built," not "let me protect
her." This frees the design from the positive-valence rule that protected the bonded pilot in
r2: losing and destruction can carry real stakes again. (Replaces r2's pilot-bond-as-heart and
the no-permanent-harm constraint.)

## The watched fight and the engineer fantasy

Because you author the body and the brain and then step back, the duel is the proof of your
*thinking* — the purest form of "engineer, not pilot." The fight must be expressive and legible
enough that alignment reads on screen, and the debrief must teach you what to change.

## The war is still the point

The defining endgame remains a living, async war where your stored ace fights other real
players' machines. The dual layer makes it richer: a stored ace fights *exactly as you designed
it* — your body and your mind — so it fights like you even while you are offline. Determinism is
the enabler and is non-negotiable: the same {body, deck, opponent, seed} must reproduce the
identical fight, so a server can re-simulate to verify a result. This also rules out a
general-purpose scripting language for the mind (no arbitrary Python): the behaviour deck
compiles to a small, restricted, deterministic, sandboxable language. Near term the war is local
seeded ghosts behind one injected opponent-build interface; the backend is a later addition the
architecture must not preclude.

## What survives from r2

Determinism and the renderer-agnostic pure sim; simulation separate from animation; the
engineer-not-pilot stance; the kitbash snap-together body; the async-PvP war endgame and the
injected opponent-build source; parts, cards, and definitions as data; Steam-PC-first /
mobile-compatible / web-optional framing; Godot 4.6 + GDScript (provisional, pending the
confirmation spike); no licensed Gundam IP (mono-eye / single visor band / full-face plate; no
V-fin, no split twin-eye, no RX-78 silhouette).

## What is dropped or reframed

The in-fight sync meter (gone — the fight is the readout). Pilot-machine *fit* as a
capacity-vs-demand number and the pre-deploy fit forecast (gone — replaced by body↔mind
alignment, seen in performance). The pilot bond as the emotional heart (reframed to pride in the
creation). The positive-valence / no-permanent-harm constraint (relaxed — no person to protect).
The detune-vs-push deploy gamble (gone — the gamble is now whether your body and deck cohere).
The three-layer constraint model with pilot-fit as the star (replaced by the two-layer
body/mind model).

## The essential version (discipline)

Build the smallest version that genuinely *is* the dual layer and can be shown: a small body (a
handful of parts under the weight/power budget), a small behaviour deck (body-gated cards), one
opponent, and a watched duel with a debrief that makes alignment legible. Everything else — a
large part/card library, the war map, multiple opponents, the networked backend, a deeper
behaviour-authoring surface — is wanted and parked.

## Open questions to settle by testing, not by argument

- **How the deck runs:** construction deck (no draw, faithful to your design) vs draw deck (hands
  + luck, more drama) vs hybrid (deterministic spine + drawn spice). A throwaway web prototype
  exists at `experiments/dual-layer-deck-combat.html` to feel this.
- **The PvP power-fairness model:** purely horizontal (power = options only), bracketed
  matchmaking (numbers climb but newcomers fight newcomers), or compressed stat spread (thin
  stats, thick invention). Unresolved.
- **How deep the behaviour surface eventually goes:** the deck is the near-term surface; a
  Carnage-Heart-style visual flow graph is a north star, not a near-term build.

## References that anchor the feeling

Carnage Heart (you program a mech's mind and watch it fight — the cult proof the fantasy is real,
and the warning about the accessibility cliff) crossed with Gundam Breaker (kitbash the body from
snap-together parts). Nobody owns the *combination* — that is the whitespace. Custom Robo for
fair, few-deep, combination-driven depth; Slay the Spire / TFT for the construction-vs-draw deck
question.
