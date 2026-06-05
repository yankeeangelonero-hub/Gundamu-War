#!/usr/bin/env bash
set -euo pipefail
cd 'D:/Claude/Mech Bags'
LOG='agent-handoffs/opus-user-journey-dispatch.log'
{
  echo "[$(date)] Waiting for existing Claude worker(s) to finish before launching Opus user-journey pass..."
  while ps -ef | grep -v grep | grep -q '/.local/bin/claude'; do
    sleep 15
  done
  echo "[$(date)] Launching Opus user-journey vision/fix pass"
  claude -p "$(cat agent-handoffs/opus-user-journey-vision-fix-prompt.md)" \
    --model opus \
    --output-format text \
    --allowedTools Read,Write,Edit,Bash \
    --dangerously-skip-permissions < /dev/null
  echo "[$(date)] Opus user-journey pass completed"
} >> "$LOG" 2>&1
