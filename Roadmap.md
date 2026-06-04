---
project: mech-bags
doc_type: roadmap
status: active
updated: 2026-06-04
---

# Roadmap — Mech Bags

## Track: Version 0.1 — Browser Prototype

Goal: A player can complete a short browser prototype run from five-bag build through ATB battle to win/loss result. No backend.

---

### M1 — V0.1 Playable Loop

**Target:** 2026-06-21
**Status:** Not started

**Goal:** One complete prototype run is playable end-to-end in a browser. Five bags, shop, bag expansions, prebuilt enemy pool, and ATB battle playback all functional.

Slices needed:
- Slice 01 — Static five-bag board shell ✗
- Slice 02 — Item placement and rotation ✗
- Slice 03 — Shop and body expansion cards ✗
- Slice 04 — Data-driven item stats and adjacency preview ✗
- Slice 05 — Deterministic ATB simulator ✗
- Slice 06 — 2D battle viewer and paused animation playback ✗
- Slice 07 — Short run loop with enemy pool ✗

**Done when:** A tester can open a single HTML file in a browser and complete a full short run (buy items, expand a bag, fight 2+ rounds of prebuilt enemies with ATB playback, reach win or loss screen) without console errors or a backend server.

---

### M2 — Prototype Tuning and Readability

**Target:** 2026-07-07
**Status:** Not started (blocked on M1)

**Goal:** Tune item synergies, battle reports, and UI clarity based on playtest feedback from M1. No new major features.

Scope (to be refined after M1):
- Adjust first item set balance based on playtesting
- Improve battle report messaging (bag source naming, key events)
- Fix any adjacency preview readability issues
- Review and address Design Reviewer feedback against `claude-design-ui-requirements.md`

**Done when:** Design Reviewer can play two full runs and confirm that bag layout, shop flow, and ATB animation readability are understandable without explanation.

---

## Future (not planned)

The following are recorded for awareness only. No dates assigned.

- Cross-bag adjacency bonuses
- Custom run lengths / difficulty settings
- Real async matchmaking
- Expanded item and mech part library
- Mobile-optimised layout
- Sound design pass
