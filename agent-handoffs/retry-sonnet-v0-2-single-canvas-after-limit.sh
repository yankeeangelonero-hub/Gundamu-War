#!/usr/bin/env bash
set -euo pipefail
cd 'D:/Claude/Mech Bags'
LOG='agent-handoffs/sonnet-v0-2-single-canvas-theatre-retry.log'
{
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Claude session limit hit; waiting until after 22:10 reset before retry."
  # Current reset reported by Claude Code: 10:10pm Asia/Singapore / local MPST.
  target_epoch=$(date -d '2026-06-05 22:12:00' +%s)
  now_epoch=$(date +%s)
  if [ "$now_epoch" -lt "$target_epoch" ]; then
    sleep $((target_epoch - now_epoch))
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Relaunching Sonnet single-canvas theatre implementation."
  claude -p "$(cat agent-handoffs/sonnet-v0-2-single-canvas-theatre-prompt.md)" \
    --model sonnet \
    --output-format text \
    --allowedTools Read,Write,Edit,Bash \
    --dangerously-skip-permissions < /dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Retry completed."
} >> "$LOG" 2>&1
