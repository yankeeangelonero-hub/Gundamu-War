---
project: mech-bags
doc_type: flow-diagram
subject: core-run-loop
status: draft
updated: 2026-06-04
---

# Core Run Loop Flow — Mech Bags Version 0.1

The run loop is the outer gameplay structure. It cycles the player through shop/build phases and battle phases until a win or loss condition is reached.

---

## Mermaid diagram

```mermaid
flowchart TD
    START([Player opens browser]) --> INIT[Initialise run\n round=1, gold=starting, bags=empty, wins=0, losses=0]
    INIT --> SHOP_PHASE

    SHOP_PHASE[Shop Phase\n Generate item offers + optional expansion card]
    SHOP_PHASE --> PLAYER_ACTS

    PLAYER_ACTS{Player action}
    PLAYER_ACTS -->|Buy item| BUY_ITEM[Deduct gold\n Add item to hand]
    PLAYER_ACTS -->|Place item in bag| PLACE_ITEM[Validate geometry\n No body-part check\n Place or reject]
    PLAYER_ACTS -->|Buy expansion card| BUY_EXPAND[Deduct gold\n Expand named bag\n Other bags unchanged]
    PLAYER_ACTS -->|Click Battle / Ready| BATTLE_PHASE

    BUY_ITEM --> PLAYER_ACTS
    PLACE_ITEM --> PLAYER_ACTS
    BUY_EXPAND --> PLAYER_ACTS

    BATTLE_PHASE[Battle Phase\n Get enemy build from pool\n Run ATB Simulator\n builds + seed → event list + result]
    BATTLE_PHASE --> SHOW_BATTLE[Play battle animation in viewer\n ATB event by event\n Update HP and log]
    SHOW_BATTLE --> RESULT_SCREEN[Show battle result\n Win/loss + reason summary]

    RESULT_SCREEN --> CHECK_RESULT{Battle result}
    CHECK_RESULT -->|Win| INC_WINS[wins += 1]
    CHECK_RESULT -->|Loss| INC_LOSSES[losses += 1]

    INC_WINS --> CHECK_WIN{wins ≥ win threshold?}
    CHECK_WIN -->|Yes| WIN_SCREEN([Run Win Screen\n Start new run?])
    CHECK_WIN -->|No| NEXT_ROUND

    INC_LOSSES --> CHECK_LOSS{losses ≥ loss threshold?}
    CHECK_LOSS -->|Yes| LOSS_SCREEN([Run Loss Screen\n Start new run?])
    CHECK_LOSS -->|No| NEXT_ROUND

    NEXT_ROUND[round += 1\n Award gold for next round]
    NEXT_ROUND --> SHOP_PHASE

    WIN_SCREEN --> INIT
    LOSS_SCREEN --> INIT
```

---

## Notes

- **Win/loss thresholds** for Version 0.1 prototype: suggested 5 wins or 3 losses, but exact values TBD during Slice 07.
- **Enemy pool** selection: `pool[round % pool.length]` or similar; no network call.
- **Build persistence across rounds**: player's placed items carry over between rounds unless explicitly sold or swapped.
- **Gold between rounds**: a fixed gold award is given at round start; exact amount TBD in Slice 03.
- The shop phase may include a reroll action (costs gold); lock mechanic is optional/deferred.
