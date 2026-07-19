#!/bin/sh
# PreToolUse hook installed by the "claude" dev container feature (mentor mode).
# Exit code 2 makes Claude Code block the tool call deterministically and feeds
# the message below back to the model.
echo "Mentor mode: writing or editing files is disabled in this environment. Guide the user so they can make the change themselves; do not attempt other ways of writing files." >&2
exit 2
