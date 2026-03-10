#!/bin/bash
# Claude Model Router v3 - PostToolUse hook
# DX feedback loops after tool execution.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('tool_input',{})))" 2>/dev/null)

ROUTER_HOME="${CLAUDE_ROUTER_HOME:-$HOME/.claude/plugins/model-router}"
LOG_DIR="$ROUTER_HOME/logs"
mkdir -p "$LOG_DIR"

# --- Track file writes for test coverage reminders ---
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null)

  if [ -n "$FILE_PATH" ]; then
    # Log the file change
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $TOOL_NAME | $FILE_PATH" >> "$LOG_DIR/file_changes.log"

    # Check if source file was changed without corresponding test
    case "$FILE_PATH" in
      *.test.* | *.spec.* | *_test.* | *_spec.*) ;;  # Test file, skip
      *.ts | *.tsx | *.js | *.jsx | *.py | *.go)
        # Check if a test file exists for this source
        DIR=$(dirname "$FILE_PATH")
        BASE=$(basename "$FILE_PATH" | sed -E 's/\.[^.]+$//')
        EXT=$(basename "$FILE_PATH" | sed -E 's/.*\.//')

        TEST_EXISTS=0
        for pattern in "${DIR}/${BASE}.test.${EXT}" "${DIR}/${BASE}.spec.${EXT}" "${DIR}/${BASE}_test.${EXT}" "${DIR}/__tests__/${BASE}.test.${EXT}"; do
          if [ -f "$pattern" ]; then
            TEST_EXISTS=1
            break
          fi
        done

        if [ "$TEST_EXISTS" -eq 1 ]; then
          echo ""
          echo "  Note: $(basename "$FILE_PATH") has a corresponding test file."
          echo "  Consider updating tests if behavior changed."
          echo ""
        fi
        ;;
    esac
  fi
fi

# --- Track slow Bash commands ---
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)

  # Log all bash commands with timestamps for session summary
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | bash | $COMMAND" >> "$LOG_DIR/session_commands.log"
fi

exit 0
