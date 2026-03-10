#!/bin/bash
# Claude Model Router v3.0 - Test Suite

PLUGIN_DIR="$HOME/.claude/plugins/model-router"
ROUTER="$PLUGIN_DIR/hooks/model_router.py"
REPORT="$PLUGIN_DIR/hooks/cost_report.py"
PASS=0
FAIL=0

echo ""
echo "+---------------------------------------------------------+"
echo "|  Model Router v3.0 - Test Suite                         |"
echo "+---------------------------------------------------------+"
echo ""

run_test() {
  local name="$1"
  local prompt="$2"
  local expected="$3"

  result=$(echo "{\"prompt\":\"$prompt\"}" | python3 "$ROUTER" 2>&1)
  if echo "$result" | grep -qi "$expected"; then
    echo "  PASS: $name -> $expected"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected $expected)"
    echo "        Got: $(echo "$result" | grep -i 'recommendation' | head -1)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Model routing tests ---

echo "  --- Haiku Tests ---"
run_test "File read" "Show me the contents of README.md" "haiku"
run_test "Quick lookup" "What is the current version?" "haiku"
run_test "Status check" "Check the status of the build" "haiku"
run_test "Short follow-up" "yes" "haiku"
run_test "Approval" "looks good do it" "haiku"
run_test "Simple view" "list all the files in src" "haiku"

echo ""
echo "  --- Sonnet Tests ---"
run_test "Error handling" "Add error handling to the user login function in auth.go" "sonnet"
run_test "Test writing" "Write unit tests for the patient lookup handler" "sonnet"
run_test "Bug fix" "Fix the null pointer in handler.py line 42" "sonnet"

echo ""
echo "  --- Opus Tests ---"
run_test "Architecture" "Design a microservices architecture for our patient data API with security guardrails and HIPAA compliance across the entire codebase" "opus"
run_test "Deep research" "Research and synthesize a comprehensive strategy for migrating our infrastructure to terraform" "opus"
run_test "Security audit" "Audit the entire authentication module for security vulnerabilities and investigate access control patterns across all services" "opus"

# --- Cost report test ---

echo ""
echo "  --- Cost Report Test ---"
if python3 "$REPORT" 2>&1 | grep -q "Cost Report\|No routing data"; then
  echo "  PASS: Cost report runs"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Cost report failed"
  FAIL=$((FAIL + 1))
fi

# --- Git hook tests ---

echo ""
echo "  --- Git Hook Tests ---"

# Test: AI trailer stripping
TEMP_MSG=$(mktemp)
cat > "$TEMP_MSG" << 'MSGEOF'
feat: add new feature

Some description here.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
MSGEOF

if [ -f "$PLUGIN_DIR/hooks/commit-msg" ]; then
  bash "$PLUGIN_DIR/hooks/commit-msg" "$TEMP_MSG" 2>/dev/null
  if grep -qi "claude\|anthropic" "$TEMP_MSG" 2>/dev/null; then
    echo "  FAIL: AI trailer not stripped"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: AI trailer stripped from commit message"
    PASS=$((PASS + 1))
  fi
else
  echo "  SKIP: commit-msg hook not installed (run with --git-hooks)"
fi

# Test: Conventional commit enforcement (should pass)
echo "feat: valid conventional commit" > "$TEMP_MSG"
if [ -f "$PLUGIN_DIR/hooks/commit-msg" ]; then
  if bash "$PLUGIN_DIR/hooks/commit-msg" "$TEMP_MSG" 2>/dev/null; then
    echo "  PASS: Valid conventional commit accepted"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Valid conventional commit rejected"
    FAIL=$((FAIL + 1))
  fi
fi

# Test: Conventional commit enforcement (should fail)
echo "bad message with no prefix" > "$TEMP_MSG"
if [ -f "$PLUGIN_DIR/hooks/commit-msg" ]; then
  if bash "$PLUGIN_DIR/hooks/commit-msg" "$TEMP_MSG" 2>&1 >/dev/null; then
    echo "  FAIL: Non-conventional commit was allowed"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: Non-conventional commit blocked"
    PASS=$((PASS + 1))
  fi
fi

# Test: Past tense detection
echo "feat: Added a new thing" > "$TEMP_MSG"
if [ -f "$PLUGIN_DIR/hooks/commit-msg" ]; then
  OUTPUT=$(bash "$PLUGIN_DIR/hooks/commit-msg" "$TEMP_MSG" 2>&1)
  if echo "$OUTPUT" | grep -qi "imperative"; then
    echo "  PASS: Past tense detected with hint"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Past tense not detected"
    FAIL=$((FAIL + 1))
  fi
fi

# Test: prepare-commit-msg
cat > "$TEMP_MSG" << 'MSGEOF'
some message

🤖 Generated with [Claude Code](https://claude.com/claude-code)
MSGEOF

if [ -f "$PLUGIN_DIR/hooks/prepare-commit-msg" ]; then
  bash "$PLUGIN_DIR/hooks/prepare-commit-msg" "$TEMP_MSG" 2>/dev/null
  if grep -qi "Generated with" "$TEMP_MSG" 2>/dev/null; then
    echo "  FAIL: prepare-commit-msg didn't strip Claude marker"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: prepare-commit-msg stripped Claude marker"
    PASS=$((PASS + 1))
  fi
else
  echo "  SKIP: prepare-commit-msg not installed"
fi

rm -f "$TEMP_MSG"

# --- Claude Code hook tests ---

echo ""
echo "  --- Claude Code Hook Tests ---"

# Test: PreToolUse runs without error
if [ -f "$PLUGIN_DIR/hooks/pre_tool_use.sh" ]; then
  echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$PLUGIN_DIR/hooks/pre_tool_use.sh" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  PASS: PreToolUse hook runs"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: PreToolUse hook errored"
    FAIL=$((FAIL + 1))
  fi
fi

# Test: PostToolUse runs without error
if [ -f "$PLUGIN_DIR/hooks/post_tool_use.sh" ]; then
  echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.py"}}' | bash "$PLUGIN_DIR/hooks/post_tool_use.sh" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  PASS: PostToolUse hook runs"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: PostToolUse hook errored"
    FAIL=$((FAIL + 1))
  fi
fi

# Test: Stop hook runs without error
if [ -f "$PLUGIN_DIR/hooks/stop_hook.sh" ]; then
  bash "$PLUGIN_DIR/hooks/stop_hook.sh" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  PASS: Stop hook runs"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Stop hook errored"
    FAIL=$((FAIL + 1))
  fi
fi

# --- Results ---

echo ""
TOTAL=$((PASS + FAIL))
echo "  --- Results ---"
echo "  $PASS/$TOTAL passed"
if [ $FAIL -gt 0 ]; then
  echo "  $FAIL tests failed"
fi
echo ""
