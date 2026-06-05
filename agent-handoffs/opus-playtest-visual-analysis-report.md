# Opus Playtest + Visual Analysis Report — Mech Bags 0.1

Date: 2026-06-04
Reviewer: Opus (Claude Code), acting as external reviewer
Scope: review-only. No source files, docs, git, or services were edited. Only this report and screenshots were written.
Build under test: `D:/Claude/Mech Bags/prototype/index.html`
Browser route: `http://localhost:8473/` (local Node static server on ephemeral port 8473, started for the session)
Evaluation lens: a **0.1 concept prototype** for "Backpack Battles, but the backpack is five mech body-part bags, and weird placement like a weapon in Head is allowed." Not judged as a production game.

---

## 1. Verdict

**Yes — Mech Bags 0.1 is a playable technical prototype, and the core concept is clearly visible.**

I played a complete run hands-on, in the browser, from the opening shop to a **RUN CLEAR** (7 rounds, 5 wins / 2 losses), exercising every required interaction: buy, place, rotate, weapon-in-Head, body expansion, adjacency synergy, battle, skip, result, and round progression. Nothing crashed. The only console message across the whole session was a harmless `favicon.ico` 404. The 66-test core suite passes 66/0.

The concept reads on first contact:
- The five bags are individually labelled and laid out in a loose mech silhouette (Head on top, Left Arm / Torso / Right Arm across the middle, Back below).
- "No anatomy police" works in practice — I bought a Beam Rifle and dropped it straight into the **Head** bag with zero friction or error styling.
- Battles resolve a deterministic ATB event stream into a paced, bag-labelled animation (`Head Beam Rifle fires!`, floating damage numbers, hit flashes, combat log).
- Body expansions visibly and locally grow the targeted bag only.

What's missing is *game*, not *prototype*: the build → battle → reward loop is real, but the strategic layer is thin (see §4, §6) and a few economy/feedback rough edges keep the "Backpack Battles depth" from landing yet. As a vertical slice proving the mechanic is alive and deterministic, it succeeds.

**Playable: yes. Concept visible: yes. Fun/strategically deep yet: not quite — that's the 0.2 job.**

---

## 2. Screenshot inventory

All under `D:/Claude/Mech Bags/agent-handoffs/opus-playtest-screenshots/`.

| File | What it shows |
|---|---|
| `01-build-start.png` | Opening state. Five labelled bag grids in mech silhouette, empty hand, 10 gold, shop row of 4 items + 1 expansion card (Sensor / Shield / Beam Rifle / Armor Plate / Back Expansion). |
| `02-beam-rifle-in-head.png` | **No-anatomy-police proof.** Beam Rifle ("BR", cyan, horizontal 1×3) placed in the **Head** bag after one rotate. Gold ticked 10→6. No error styling. |
| `03-back-expansion.png` | **Body expansion proof.** After buying Back Expansion (4g), the Back grid grew from 3×2 (6 cells) to 4×2 (8 cells). Only Back changed; all other bags unchanged. |
| `04-adjacency-synergy.png` | **Synergy proof.** Targeting Chip ("TC", green) placed directly under the Beam Rifle in Head; the rifle's three cells now carry the brighter `has-bonus` border (+15% crit from the adjacent chip). |
| `05-battle-in-progress.png` | Battle screen mid/late combat. Banner `Back Machine Gun fires!`, bag-labelled combat log (`[Head] Beam Rifle — CRIT! 33 dmg`, `[Back] Machine Gun dealt 8 dmg`), player HP 0/80 vs enemy 11/110. Build board faintly visible behind the overlay. |
| `06-battle-event.png` | **Best single combat frame.** Banner `Torso Beam Saber fires!`, a floating `-16` damage number with an orange hit-flash anchored on the player's torso, bag-labelled log including `[Head] Beam Rifle — missed!` and `[Back] Missile Pod dealt 28 dmg`. Player HP 9/85, enemy 32/80. |
| `07-result-defeat.png` | Round 1 result overlay: "DEFEAT!", "+4g next round", "Your **Head** was your best bag — 99 total damage", "14 attack events", yellow Continue button. |
| `08-skip-to-result.png` | Skip-Battle outcome (Round 3 vs Beam Head Goblin): instant "VICTORY!" overlay with the full instant-resolved log faded behind. |
| `09-run-clear.png` | Run-end screen: "RUN CLEAR!", "Round 7 \| Wins 5 \| Losses 2", "Start New Run" button. |
| `10-hand-and-info.png` | Hand/Info/shop reference: two Ammo Box items in Hand (each with a `$1` sell chip), Item Info panel populated, Rotate enabled, Ammo Box shop card still present after two purchases (shop-not-consumed). |

---

## 3. Visual analysis

**Board readability — good silhouette, weak grid contrast.**
The five-bag mech silhouette is the strongest visual idea and it works: a glance tells you Head/Torso/Back/Arms are distinct containers. But the empty grid cells are very dark (near-black on a graphite background), so an *empty* board reads as a vague cluster of dark rectangles rather than crisp Tetris-style cells. Item-occupied cells, by contrast, pop nicely (saturated tag colors with a lightened border). The contrast gap between "empty cell" and "background" is the single biggest readability fix.

**Hierarchy & layout — heavy dead space.**
At 1440×900 the board floats in the centre with enormous empty margins left and right (~30% of the width on each side is unused). The Hand/Rotate/Info side panel is pinned far right, physically distant from both the board and the shop. Vertically there is also a large gap between the board and the shop strip. The composition is functional but uneconomical; it reads as "placeholder layout" rather than designed framing.

**Shop clarity — clear and honest.**
Shop cards are legible: color bar, name, cost in gold, one-line description. Expansion cards are visually distinct (blue bar, "+1 row to X" copy). Cards you can't afford get a dimmed `cant-afford` treatment. This is the most production-ready surface in the build.

**Bag identity — names yes, theming no.**
Bags are identified purely by their text label and silhouette position. There is no per-bag iconography, color, or framing to reinforce "this is the Head / this is the Back." For a five-bag fantasy this is the obvious place to add cheap identity (a small icon per bag, a tint).

**Item shapes — correct but abbreviation-coded.**
Shapes occupy the right cells and rotation visibly re-flows them. Items are labelled only by a 2-letter abbreviation on the anchor cell ("BR", "TC", "BS"), with the full name in a native `title` tooltip. There are no item icons. It's readable once you learn the abbreviations, but "BR/BS" (Beam Rifle / Beam Saber) are easy to confuse at a glance.

**Color / contrast — tag coding is good, UI chrome is muddy.**
The tag palette is well chosen and matches the brief (cyan beams, red/orange ballistic & explosive, green sensor/economy, grey armor, yellow power). The problem is the dark-on-dark chrome: empty cells, panel borders, and the battle overlay all sit in a narrow low-contrast band of greys.

**Typography — consistent monospace, occasionally cramped.**
A single monospaced family is used throughout, which suits the "toy-tactical garage" tone. The Item Info panel and card descriptions wrap tightly and can feel dense. Headers and result titles are appropriately large and colored (green win / red loss).

**Combat readability — strong where it counts.**
The combat log is the standout: every line is prefixed with its bag (`[Torso] Beam Saber dealt 16 dmg`), color-coded by outcome (player / enemy / miss / block / crit), and auto-scrolls. The event banner names the firing bag + weapon. Floating damage numbers and hit flashes are anchored to the struck body part. This is exactly the readability the brief asked for. Two weaknesses: the mech sprites themselves are near-empty placeholder boxes with a single glyph (👁 / ☠), so the "animation plays *from the bag anchor*" intent is only weakly legible; and the battle overlay is semi-transparent, so the build board bleeds through behind the arena (visible in `05`/`07`), which muddies the scene.

---

## 4. Game-feel analysis

**Does the five-bag Backpack-Battles mech fantasy read? — Partially, and promisingly.**
The *spatial* fantasy lands: you really are stuffing shaped parts into five separate containers and the silhouette makes it feel like kitting out a mech. What does **not** yet land is the *consequence* of which bag you choose. Because there are no placement restrictions and (in 0.1) no per-bag mechanical effects, a weapon in Head behaves identically to the same weapon in Left Arm — the only thing the bag changes is the cosmetic firing anchor and the log label. So the five bags currently read as "one inventory drawn in five boxes" more than "five meaningfully different mounts." That's fine for 0.1, but it's the central thing 0.2 must give weight to, or the five-bag idea stays cosmetic.

**Is "no anatomy restriction" communicated? — It is *permitted* but not *celebrated*.**
Placing a Beam Rifle in the Head just works, silently. There is no moment of "ha, you put a rifle on its head" — no reaction, no flavour, no reward. The brief explicitly wants weird placements to feel *amusing and valid*, not merely *allowed*. Right now a new player might not even realise the placement is unusual, because nothing acknowledges it. The freedom is real but invisible.

**Do expansions feel meaningful? — Mechanically yes, strategically not yet.**
Buying Back Expansion visibly added a row to exactly the Back bag (`03`), which satisfies the "see which bag will change" invariant. But because every bag is interchangeable and gold is abundant, "which bag do I grow" isn't a real decision — you grow whichever bag you happen to be filling. Expansions today are "+1 generic space" rather than "commit to a Back-heavy build." There's no directional tension (e.g. a reason to specialise one bag) so the expansion never becomes a *build decision*, which the design goals specifically call for.

**Overall feel.**
The loop is satisfying in the mechanical sense — buy, fit the puzzle, watch it fight, get gold, repeat. But two things flatten it: (a) the same modest build I assembled by Round 2 (Beam Rifle + Targeting Chip in Head, Beam Saber in Torso) went on to win 4 of the next 5 fights untouched, and I ended the run sitting on **17+ unspent gold**; and (b) enemies are a fixed round-indexed rotation `(round-1) % 6` with **no scaling**, so the run gets *easier* as your build grows and your gold piles up with nothing urgent to buy. The puzzle is fun; the economy and difficulty curve don't yet create pressure.

---

## 5. Battle / ATB analysis

**Event timing readability — good, and not too fast for a human.**
Each event animates at roughly 0.7s (≈270–460ms projectile travel + 160ms + 220ms settle), so a real player watches a readable, paced sequence. (My automated screenshots kept landing late in the battle because each browser tool round-trip costs ~1s, which outran the start-frame — that's a capture artifact, not a pacing problem. The ATB is comfortably watchable.) The single-animation-at-a-time rule from the brief holds: I never saw two primary attack animations competing.

**Animation anchoring — directionally correct, visually thin.**
Projectiles originate from the firing bag's anchor on the source sprite and fly to the target's torso; hit flashes and damage numbers land on the struck part (clearly visible in `06`). The *logic* of "fires from the bag" is implemented. The *readability* is limited by the sprites being empty placeholder boxes, so you read the source from the **banner/log text** more than from the visual. Projectile types vary by tag (beam / bullet / missile) with different speeds, which is a nice touch.

**Combat log — the best-realised feature.**
Bag-prefixed, outcome-colored, auto-scrolling, and it names the bag source for weird builds exactly as the invariant requires (`[Head] Beam Rifle — CRIT! 33 dmg`). This is what makes the battles legible despite the placeholder sprites.

**Skip Battle — works, instant, correct.**
Clicking Skip immediately aborts the animation loop, sets the banner to "⚡ VICTORY!" / "💀 DEFEAT!", dumps the full resolved log at once, disables the button, and rolls to the result overlay after ~600ms. Result is identical to the watched outcome (same deterministic event stream). No double-trigger issues observed.

**Result flow — clear and informative.**
The result overlay reports winner, gold reward, **best bag by damage** (a genuinely nice build-feedback hook: "Your Head was your best bag — 99 total damage"), final HP for both sides, and event count. Continue advances the round. The full run terminates correctly at 5 wins (RUN CLEAR) / 3 losses, with a dedicated end screen and New Run reset.

**ATB correctness spot-check (determinism).**
I ran `simulate()` twice with an identical seed in-browser: byte-identical 7-event signatures. A different seed produced a different stream. Determinism (the hard ARC requirement) holds. Shop generation uses `Math.random()` but is correctly walled off from the battle sim, so it cannot affect battle determinism.

---

## 6. UX friction — top 10, ranked by severity

1. **Shop offers are never consumed → infinite copies, broken scarcity.** (High) After buying an item the card stays in the shop; I bought Ammo Box twice from the same card with no reroll (`10-hand-and-info.png`). This removes the core Backpack-Battles tension of "take it now or lose it" and makes Reroll nearly pointless — you never *need* to reroll to re-acquire anything. See §7 (confirmed).
2. **Bags are mechanically interchangeable → the five-bag premise is cosmetic.** (High) Nothing about *which* bag an item lives in changes its behaviour beyond the firing anchor/label. The headline fantasy has no mechanical teeth yet.
3. **Weird placement is permitted but never acknowledged.** (High) Putting a rifle on the Head produces no flavour, reaction, or reward. The "funny/cursed builds are valid" goal is invisible to the player.
4. **No mid-battle pacing control / it can feel like it just happens.** (Medium) There's only Skip — no speed control and no "advance one event" step. A player who wants to *study* a fight can only watch at fixed speed or skip entirely.
5. **Economy has almost no sink; gold piles up.** (Medium) I finished the run with 17+ unspent gold. With items cheap (2–5g), rewards generous (4–6g/round), and no consumption, money stops being a constraint within a few rounds.
6. **Synergy feedback is too subtle.** (Medium) An active adjacency bonus only shows as a slightly brighter cell border plus a line *inside the Item Info panel for the selected item*. With nothing selected, an active synergy is nearly invisible (`04`). No badge, no connecting line, no "synergy active" callout on the board.
7. **Difficulty does not scale; the run gets easier.** (Medium) Enemies are a fixed `(round-1) % 6` rotation. As your build compounds and gold accrues, later rounds are softer than early ones — the Round 1 enemy reappears at Round 7 and is trivial.
8. **Mech sprites are empty placeholder boxes.** (Medium) The arena communicates almost entirely through text. The "animation plays from the body part" intent is logically there but barely visible, undercutting the mech-fantasy payoff of the battle screen.
9. **Empty-cell contrast + dead layout space.** (Low–Medium) Empty grids are near-invisibly dark and the board floats in large empty margins; the build screen reads as unfinished framing.
10. **Items identified only by 2-letter abbreviations; "BR" vs "BS" collide.** (Low) No icons; full names live in a native tooltip only. Learnable, but momentarily ambiguous, especially the two beam weapons.

---

## 7. Bugs / suspected bugs

### Confirmed

**C1 — Shop offers are not removed after purchase (infinite buy).**
Repro: open prototype → buy any shop item → the same card remains and can be bought again immediately.
Evidence: bought "Ammo Box" twice from one card; gold 10→8→6, Hand grew to 2 copies, card still present (`10-hand-and-info.png`). Source: `onShopCardClick` (app.js) deducts gold and pushes to hand but never removes the offer from `state.shop`; `renderShop` re-renders the same offers.
Impact: breaks shop scarcity and trivialises Reroll. Likely a design decision that needs revisiting rather than a crash, but it materially changes the game.

**C2 — Header "Wins" counter lags by one on the run-clearing victory.**
Repro: reach 4 wins → win the 5th → on Continue, the header still shows "Wins 4" while the run-end screen correctly shows "Wins 5".
Evidence: in-DOM read returned header `stat-wins = "4"` while `end-stats = "Wins 5"` at run clear (`09-run-clear.png` shows 5 on the end screen). Source: `onResultContinue` increments `state.wins` then early-returns into `showRunEnd` *before* `renderHeader`/`renderAll` runs, so the header never repaints for the final win.
Impact: cosmetic only; the authoritative end-screen total is correct.

### Suspected / edge cases (not a problem in normal play, flagged for awareness)

**S1 — A build with zero damage-dealing items auto-wins if the opponent also has none.**
`simulate()` short-circuits to `{ winner: 'player' }` when `allAttackers.length === 0`. In practice every enemy in the pool carries weapons, so a weaponless player will instead be ground down and *lose* (enemy attackers fire, player never does). The default-player-win branch only triggers if **neither** side has a weapon, which the static enemy pool prevents. Worth a guard/explicit handling before player-vs-player or weaponless enemies are ever introduced.

**S2 — Battle overlay is semi-transparent; the build board bleeds through.**
Visible in `05`/`07` — the arena sits over a not-fully-opaque backdrop, so bag grids and labels ghost through behind the fight. Cosmetic, but it reduces battle-scene clarity.

**S3 — `favicon.ico` 404 in console.** The only console error all session. Pure noise; add a favicon or a `<link rel="icon">` data-URI to silence it.

No data loss, no determinism break, no crash, no stuck state encountered across a full 7-round run plus a second fresh run.

---

## 8. 0.2 recommendations (prioritized, small-slice sized)

Aim each at one self-contained slice; do **not** redesign.

**P0 — Make the shop consume offers (Slice: shop-consumption).** Remove a purchased offer from `state.shop` (replace with a sold-out placeholder or blank). This single change restores Backpack-Battles scarcity, makes Reroll meaningful, and tightens the economy — the highest gameplay value for the least code. Pair with a small gold-sink check (slightly raise costs or lower rewards) so money stays a real constraint.

**P1 — Give bags one cheap mechanical identity (Slice: bag-traits).** The smallest version of the core promise: a single per-bag modifier (e.g. Head = +accuracy, Arms = +melee speed, Back = +explosive damage, Torso = +HP). Now "rifle in Head vs rifle in Arm" is an actual decision and expansions become directional ("go Back-heavy"). This is what converts the five-bag idea from cosmetic to mechanical.

**P2 — Acknowledge cursed placements (Slice: placement-flavour).** When a weapon goes into a "weird" bag, fire a tiny flavour line / badge ("Beam Rifle mounted on Head 🤪") and surface it in the result copy. Cheap, on-brand, and finally makes "no anatomy police" a *feature the player feels*, not just a missing restriction.

**P3 — Strengthen synergy feedback (Slice: synergy-readability).** Add an always-on "⚡ synergy active" badge/glow on the board (independent of selection) and a connecting tick between the two adjacent items. The math already exists in `getActiveBonuses`; this is presentation only.

**P4 — Lift empty-cell contrast + tighten layout (Slice: board-contrast).** Lighten empty `.bag-cell` backgrounds/borders so the grid reads when empty, and pull the board/side-panel/shop closer together to kill the dead margins. Pure CSS.

**P5 (stretch) — Light difficulty scaling (Slice: enemy-scaling).** Instead of a flat `(round-1) % 6` rotation, scale enemy HP/damage modestly by round, or order the pool by difficulty, so the curve rises with the player's build.

Deliberately **not** recommended for 0.2: real sprites/art pass, animation speed controls, new item tiers, or any backend — all out of scope for the next small slice.

---

## 9. Keep / cut / change

**Keep**
- The five-bag silhouette board and the spatial-puzzle placement — the concept's heart, and it works.
- "No anatomy police" — placement freedom is real and frictionless.
- The deterministic two-phase ATB (simulate → playback) — clean architecture, verified deterministic, paced and readable.
- The bag-labelled, outcome-colored combat log and the "best bag by damage" result hook — genuinely good feedback.
- Skip Battle and the full run loop (win/loss thresholds, run-end, New Run) — complete and correct.

**Cut / fix**
- Infinite shop re-buying (consume offers).
- The interchangeable-bags status quo — bags must start meaning something.
- Dead layout space + invisible empty cells.
- The lagging header win counter (C2) and favicon 404 (S3).

**Change**
- Turn expansions from "+1 generic space" into directional build commitments (follows from bag identity).
- Make weird placements *celebrated*, not merely *permitted*.
- Add a real gold sink / mild difficulty scaling so mid-late run keeps tension.

**Direction in one line:** the prototype proves the *mechanic* (five bags, free placement, deterministic ATB) is alive and readable; 0.2's job is to make *which bag* matter and to restore *scarcity*, turning a working toy into a decision-rich game.

---

## 10. Test evidence

**Commands run**
- `node prototype/tests/core-tests.js` → **66 passed, 0 failed.** Covers rotation, placement validation incl. BEH-001 (Beam Rifle placeable in Head, no anatomy check), bag expansion (BEH-002, only target bag grows), adjacency bonuses (exact deltas, e.g. Battery −20 speed to Beam Rifle), event schema fields, all six enemy builds conflict-free, run thresholds, and sell-price math.
- In-browser `simulate()` determinism check: same seed → byte-identical 7-event signature (`sameSeedIdentical: true`); different seed → different signature. Shop RNG (`Math.random`) confirmed walled off from the sim.

**Browser route**
- Served the static prototype via a Node http server on ephemeral port **8473**; loaded `http://localhost:8473/`. Viewport 1440×900, Playwright-driven Chromium.

**Console errors**
- One only, on every load: `Failed to load resource: 404 (Not Found) @ /favicon.ico`. No JavaScript errors, no warnings, across a full 7-round run plus a second fresh run.

**Hands-on run timeline (deterministic; build carried across rounds)**

- **Round 1** — vs *Starter Balanced*. Build: single Beam Rifle (Head). Result **DEFEAT** 0/80 vs 11/110, 14 events; result screen attributed `Head — 99 total damage` (enemy 110→11 checks out). A lone 22-dmg/100-speed rifle loses the DPS race to an 8-dmg/40-speed machine gun behind +30 armor HP.
- **Round 2** — vs *Missile Backpack*. Added Beam Saber (Torso) + Targeting Chip (Head, adjacent to rifle → +15% crit, `has-bonus` glow on all 3 rifle cells; player max HP became 85 = 80 + 5 from the chip). Result **VICTORY** 9/85 vs 0/80, 10 events; best bag `Torso — 64`. Captured the cleanest combat frame here (`-16` damage number + flash on player torso, `06-battle-event.png`).
- **Round 3** — vs *Beam Head Goblin*. Used **Skip Battle**: instant "⚡ VICTORY!", full 10-line log dumped at once, skip button disabled, result after ~600ms. Best bag `Torso — 80`, 8/85 vs 0/85. (Fittingly beat the beam-rifle-in-Head enemy.)
- **Round 4** — vs *Shield Turtle*. Skip → **DEFEAT** (the 48-dmg Heavy Cannon + Shield/Armor wall out-tanks an 85-HP build). Losses → 2.
- **Round 5** — vs *Saber Rush*. Skip → **VICTORY**. Gold sitting at 17 unspent.
- **Round 6** — vs *Heavy Cannon Glass Cannon*. Skip → **VICTORY**. Wins → 4.
- **Round 7** — vs *Starter Balanced* (pool wraps via `(round-1) % 6`). Skip → **VICTORY** → **RUN CLEAR**. End screen: `Round 7 | Wins 5 | Losses 2` (header momentarily still read "Wins 4" — bug C2).

**Load-bearing invariants observed**
- Determinism: identical seed → identical event stream (in-browser check + 66-test suite).
- No-anatomy-police: Beam Rifle placed in Head with zero restriction; placement rejects only on geometry/overlap/bounds.
- Local expansion: buying Back Expansion grew only Back (6→8 cells); all other bags unchanged.
- Network-zero: entire run played from a local static file server; no outbound requests beyond the favicon probe.
- Run termination: run ended deterministically at the 5-win threshold with a dedicated end screen and working New Run reset.
