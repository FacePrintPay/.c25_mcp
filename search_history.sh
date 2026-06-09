#!/bin/bash
# Search Termux bash history for Planetary Agents commands

HIST_FILE="$HOME/.bash_history"
if [[ ! -f "$HIST_FILE" ]]; then
  echo "No bash history found"
  exit 0
fi

echo "🔍 Searching bash history for Planetary Agents commands..."
echo "=========================================================="

grep -iE "agent|c25|constellation|planetary|deploy|mcp" "$HIST_FILE" | \
  tail -100 | \
  sort -u | \
  nl

echo ""
echo "Total commands found: $(grep -ciE 'agent|c25|constellation|planetary' "$HIST_FILE" 2>/dev/null || echo 0)"
