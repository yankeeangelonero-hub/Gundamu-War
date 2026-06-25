---
project: kitbash-mecha
repo: gundamu-war
artefact: research-document
doc_type: flow
status: frozen
created: 2026-06-07
cites: Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md
---

# Flow — Dual-layer core loop (r3)

The engineer authors a **body** and a **mind**, deploys, watches whether the two align, learns
from the debrief, and iterates. Granularity is "what surface am I on and what did I just author
or see" — not micro-interactions inside a screen. Supersedes the r2 core-loop
(`docs/wishlist/flows/core-loop.mmd`) and the Mech Bags run loop
(`Research/flows/run-loop-flow.md`).

```mermaid
flowchart TD
    Hangar["Hangar — author the BODY\nkitbash parts onto the frame under the weight/power budget;\nsets what the machine CAN do + its silhouette"]
    Doctrine["Doctrine bench — author the MIND\nbuild her behaviour deck; cards are gated by the body\n(saber cards need a saber)"]
    Check{"Do body and mind cohere?\ndead cards greyed; player reads the deck against the build"}
    Deploy["Deploy\nhand body + mind to the war (point of no control)"]
    Watch["Watch the duel\nthe deck runs itself; alignment plays out on screen —\nno meter, the fight IS the readout"]
    Result{"Result"}
    Debrief["Debrief — why it played out\nnarrates the misses: dead cards, whiffs, hesitations;\nwhat aligned and what fought itself"]
    Home["Homecoming\ncollect new parts + cards = WIDER vocabulary to invent with\n(never bigger numbers)"]

    Hangar --> Doctrine
    Doctrine --> Check
    Check -->|"gaps — fix the body or the deck"| Hangar
    Check -->|"coheres — commit"| Deploy
    Deploy --> Watch
    Watch --> Result
    Result -->|"won, read why it worked"| Debrief
    Result -->|"lost, learn why"| Debrief
    Result -->|"won clean"| Home
    Debrief --> Hangar
    Home --> Hangar
```

The most likely failure/recovery path is the **Debrief → Hangar** edge: a loss (or an ugly win)
sends the player back to re-author the body or the deck, having been told exactly which cards
were dead, whiffed, or never fired. The loop is legible by construction — the fight and the
debrief are the only feedback, and both point at alignment.
