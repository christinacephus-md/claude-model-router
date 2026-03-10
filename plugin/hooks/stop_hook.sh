#!/bin/bash
# Claude Model Router v3 - Stop hook
# Generates a session summary when Claude Code finishes a conversation turn.

ROUTER_HOME="${CLAUDE_ROUTER_HOME:-$HOME/.claude/plugins/model-router}"
LOG_DIR="$ROUTER_HOME/logs"
COST_LOG="$LOG_DIR/cost_log.csv"
SESSION_LOG="$LOG_DIR/session_summary.log"

mkdir -p "$LOG_DIR"

# Get today's routing stats
TODAY=$(date +%Y-%m-%d)
if [ -f "$COST_LOG" ]; then
  HAIKU_COUNT=$(grep "$TODAY" "$COST_LOG" | grep -c "haiku" || echo "0")
  SONNET_COUNT=$(grep "$TODAY" "$COST_LOG" | grep -c "sonnet" || echo "0")
  OPUS_COUNT=$(grep "$TODAY" "$COST_LOG" | grep -c "opus" || echo "0")
  TOTAL=$((HAIKU_COUNT + SONNET_COUNT + OPUS_COUNT))

  # Calculate estimated cost
  EST_COST=$(grep "$TODAY" "$COST_LOG" | awk -F',' '{sum += $8 + $9} END {printf "%.2f", sum}' 2>/dev/null || echo "0.00")
else
  HAIKU_COUNT=0
  SONNET_COUNT=0
  OPUS_COUNT=0
  TOTAL=0
  EST_COST="0.00"
fi

# Count file changes this session
FILE_CHANGES=0
if [ -f "$LOG_DIR/file_changes.log" ]; then
  FILE_CHANGES=$(grep -c "$TODAY" "$LOG_DIR/file_changes.log" 2>/dev/null || echo "0")
fi

# Count git operations
GIT_OPS=0
if [ -f "$LOG_DIR/git_operations.log" ]; then
  GIT_OPS=$(grep -c "$TODAY" "$LOG_DIR/git_operations.log" 2>/dev/null || echo "0")
fi

# Only show summary if there's meaningful activity
if [ "$TOTAL" -gt 0 ] || [ "$FILE_CHANGES" -gt 0 ]; then
  SUMMARY=$(cat <<SUMMARY_EOF

  +---------------------------------------------------------+
  |  Session Summary                                        |
  +---------------------------------------------------------+

  Routing:  $TOTAL prompts (H:$HAIKU_COUNT S:$SONNET_COUNT O:$OPUS_COUNT)
  Est cost: \$$EST_COST today
  Files:    $FILE_CHANGES changes tracked
  Git ops:  $GIT_OPS operations

SUMMARY_EOF
  )

  echo "$SUMMARY"

  # Append to session log
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | prompts=$TOTAL h=$HAIKU_COUNT s=$SONNET_COUNT o=$OPUS_COUNT est=\$$EST_COST files=$FILE_CHANGES git=$GIT_OPS" >> "$SESSION_LOG"
fi

exit 0
