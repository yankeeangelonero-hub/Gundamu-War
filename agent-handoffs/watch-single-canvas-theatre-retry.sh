#!/usr/bin/env bash
set -euo pipefail
cd 'D:/Claude/Mech Bags'
LOG='agent-handoffs/sonnet-v0-2-single-canvas-theatre-watch.log'
REPORT='agent-handoffs/sonnet-v0-2-single-canvas-theatre-report.md'
{
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Watcher started. Waiting for active Claude Code process to finish..."
  while ps -ef | grep -v grep | grep -q '/.local/bin/claude'; do
    sleep 20
  done
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Claude process no longer active. Checking report/tests."
  if [ -f "$REPORT" ]; then
    echo "Report present: $REPORT"
  else
    echo "Report missing: $REPORT"
  fi
  node prototype/tests/core-tests.js || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Watcher done."
} >> "$LOG" 2>&1
