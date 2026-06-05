# Opus Agent Task — Mech Bags user-journey vision playtest + fix pass

You are Claude Code Opus running inside `D:/Claude/Mech Bags`.

Xuanyue asked Hermes to pass the user-journey requirements to an Opus agent and ask it to **test through vision** and **fix any user-journey issues**.

## Critical coordination note

A Sonnet mobile-placement bugfix worker may have just completed or may have left changes in the tree. Do not assume the baseline is the older desktop-only design. Start by inspecting `git status --short` and the latest handoff reports under `agent-handoffs/`, especially:
- `claude-frontend-design-implementation-report.md`
- `claude-mobile-placement-bugfix-report.md` if present
- `claude-mobile-placement-bugfix-prompt.md`

If another Claude/Hermes worker is actively editing files, do not race it. Report the conflict and stop after writing your report. Otherwise proceed.

## Ground rules

- This is a high-stakes UX/journey QA + fix pass, not a broad redesign.
- Preserve the current distinctive “Armored Maintenance Bay / tactical garage / diecast mech kit” visual language unless a change is needed for journey clarity.
- Do not commit, push, delete existing screenshots, or alter unrelated project scaffolding.
- Preserve gameplay/product contract:
  - five independent bags: Head, Torso, Back, Left Arm, Right Arm;
  - item placement is unrestricted by anatomy; Beam Rifle in Head is valid when geometry/rotation permits it;
  - placement validation is geometry/overlap/out-of-bounds only;
  - keep deterministic ATB simulator, shop, expansion, adjacency, battle, result, run-clear/run-over behavior;
  - static no-dependency browser prototype; no backend/accounts/network gameplay.
- Favor small targeted fixes that improve real player journeys.

## Required reading before testing or editing

Read:
- `Readme.md`
- `Kanban.md`
- `prototype/README.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- current/previous handoff reports in `agent-handoffs/`

## User journeys to test and protect

### Journey 1 — First-Time Player: “What is this game?”
Goal: understand the loop quickly and place the first mech item.
Steps:
1. open prototype;
2. see five named body-part bags;
3. buy a cheap item;
4. item appears in hand;
5. select/tap item, then click/tap valid grid cell;
6. item appears on that bag;
7. press Battle;
8. understand win/loss and rewards.
Success: “I get it — buy parts, arrange them in body bags, test the build.”
Risk: unclear placement feedback makes the game feel broken.

### Journey 2 — Experimenter: “Can I put weird weapons anywhere?”
Goal: discover unrestricted body-part placement.
Steps:
1. buy Beam Rifle / Missile Pod / other weapon;
2. try placing it in an unusual bag like Head;
3. game allows it if geometry fits;
4. player realizes this is spatial strategy, not anatomy simulation.
Success: “Beam Rifle in Head is valid.”
Risk: visuals/copy imply anatomy restrictions or silently reject valid attempts.

### Journey 3 — Optimizer: “How do I make a stronger build?”
Goal: learn adjacency, stats, and synergies.
Steps:
1. buy multiple items;
2. inspect item info;
3. move items to activate same-bag adjacency;
4. visible green glow/bonus tags confirm synergy;
5. compare battle performance.
Success: “Arrangement matters, not only price.”
Risk: adjacency feedback too subtle or stats are unreadable.

### Journey 4 — Expansion Planner: “Which body part should I grow?”
Goal: understand expansion as strategic identity.
Steps:
1. buy a named expansion card;
2. only that body-part bag gains a row;
3. player sees what changed;
4. player specializes or spreads build.
Success: “My Head/Back/etc. is now a weapon/support platform.”
Risk: expansion feedback is not obvious.

### Journey 5 — Short-Run Player: “Can I clear a run?”
Goal: complete the short run loop.
Steps:
1. start with limited gold;
2. buy/place/battle;
3. receive rewards;
4. build persists;
5. continue until 5 wins or 3 losses;
6. see RUN CLEAR or RUN OVER.
Success: “I built a mech that survived the run.”
Risk: continuation/reward/run progress unclear.

### Journey 6 — Mobile Player: “Can I play this on my phone?”
Goal: buy, place, rotate, and battle using touch only.
Steps:
1. open prototype on mobile/narrow viewport;
2. buy item;
3. tap hand item to select;
4. tap grid cell to place;
5. invalid fit visibly explains rotate/choose another cell;
6. use Rotate button, not keyboard;
7. place successfully;
8. battle/result screens remain readable.
Success: “I can play without keyboard or desktop mouse.”
Risk: silent invalid placement is fatal; hidden horizontal overflow makes controls unreachable.

## Testing requirements — must use vision/browser-style inspection

Use whatever browser/vision path is available to Claude Code on this host. If Playwright/Chrome integration is unavailable, use the strongest available fallback and document the limitation. The goal is hands-on visual journey testing, not only code review.

Required visual/manual states to inspect and/or screenshot:
1. fresh build screen;
2. after buying an item;
3. valid item placed on a bag;
4. Beam Rifle or other shape-sensitive weapon placed in Head if geometry allows;
5. adjacency/synergy visible state;
6. expansion purchased and changed bag visible;
7. battle screen mid-combat;
8. post-battle result;
9. run end if practical;
10. narrow/mobile viewport placement flow.

Place screenshots, if captured, under:
`agent-handoffs/opus-user-journey-screenshots/`

## Fix scope

If you find user-journey issues, fix them directly with minimal targeted edits. Examples of acceptable fixes:
- clearer onboarding microcopy or status text;
- visible success/failure placement feedback;
- clearer rotate hint for touch users;
- stronger expansion/row-added feedback;
- more obvious adjacency indicators or item-info explanation;
- responsive layout fixes for mobile reachability/readability;
- battle/result/continue copy improvements;
- accessibility/focus/readability fixes.

Do not rework core simulation or add new gameplay systems unless a journey is impossible without a tiny behavior-supporting change.

## Verification required

Run and report:
- `node prototype/tests/core-tests.js`

Also do browser/vision journey checks and document exact steps/results. If any journey cannot be fully completed, say why and whether it is a product issue or test-environment limitation.

## Report required

Write exactly one final report artifact:
`agent-handoffs/opus-user-journey-vision-fix-report.md`

Report structure:
1. Summary verdict
2. User journey results table: Journey, status PASS/PARTIAL/FAIL, evidence, issues found, fixes applied
3. Files changed
4. Screenshots captured
5. Gameplay invariants preserved
6. Verification commands/results
7. Remaining risks / recommended next pass

If no code fixes are necessary, still write the report with evidence and screenshots.

## Success criteria

- All six journeys are tested through visual/manual interaction as far as the environment permits.
- Any journey-blocking issue is fixed or clearly reported with reason.
- Valid placement and unrestricted body-part placement remain intact.
- Mobile/touch placement is understandable.
- Tests pass.
