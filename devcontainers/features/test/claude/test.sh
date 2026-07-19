#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "claude CLI" claude --version
check "user memory (CLAUDE.md)" test -s "$HOME/.claude/CLAUDE.md"
check "mentor output style" test -s "$HOME/.claude/output-styles/mentor.md"
check "settings deny file edits" grep -q '"Write"' "$HOME/.claude/settings.json"
check "settings deny git commit" grep -q 'git commit' "$HOME/.claude/settings.json"
check "hook is executable" test -x "$HOME/.claude/hooks/deny-file-edits.sh"
# shellcheck disable=SC2016
check "hook blocks with exit 2" bash -c '"$HOME/.claude/hooks/deny-file-edits.sh" 2>/dev/null; [ $? -eq 2 ]'
# shellcheck disable=SC2016
check "config owned by user" bash -c '[ "$(stat -c %U "$HOME/.claude")" = "$(id -un)" ]'

reportResults
