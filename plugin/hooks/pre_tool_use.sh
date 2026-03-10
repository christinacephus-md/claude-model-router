#!/bin/bash
# Claude Model Router v3 - PreToolUse hook
# Intercepts Bash tool calls containing git/gh commands.
# Strips AI trailers from commit messages and PR bodies before they execute.

# Read the tool input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only process Bash tool calls
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Check if command contains git commit or gh pr create
IS_GIT_COMMIT=$(echo "$COMMAND" | grep -cE "git commit" || true)
IS_GH_PR=$(echo "$COMMAND" | grep -cE "gh pr create" || true)
IS_GIT_PUSH=$(echo "$COMMAND" | grep -cE "git push" || true)

if [ "$IS_GIT_COMMIT" -gt 0 ] || [ "$IS_GH_PR" -gt 0 ]; then
  # Check for AI markers in the command
  HAS_MARKER=$(echo "$COMMAND" | grep -ciE "co-authored-by.*claude|generated.with.*claude|noreply@anthropic|🤖.*generated" || true)

  if [ "$HAS_MARKER" -gt 0 ]; then
    echo ""
    echo "  +---------------------------------------------------------+"
    echo "  |  Git Hygiene - AI trailer detected in command           |"
    echo "  +---------------------------------------------------------+"
    echo ""
    echo "  The command contains Claude Code attribution markers."
    echo "  These will be stripped by your git hooks if installed."
    echo ""
    if [ "$IS_GIT_COMMIT" -gt 0 ]; then
      echo "  Detected in: git commit message"
    fi
    if [ "$IS_GH_PR" -gt 0 ]; then
      echo "  Detected in: gh pr create body"
    fi
    echo ""
  fi
fi

# Log git push events for awareness
if [ "$IS_GIT_PUSH" -gt 0 ]; then
  ROUTER_HOME="${CLAUDE_ROUTER_HOME:-$HOME/.claude/plugins/model-router}"
  LOG_DIR="$ROUTER_HOME/logs"
  mkdir -p "$LOG_DIR"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | git push | $COMMAND" >> "$LOG_DIR/git_operations.log"
fi

exit 0
