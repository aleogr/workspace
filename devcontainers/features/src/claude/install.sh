#!/bin/sh
set -e

CLAUDE_VERSION=${VERSION:-"stable"}
TEACHER_MODE=${TEACHERMODE:-"true"}

FEATURE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Starting Claude Code installation..."

if ! command -v curl >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing curl, bash and ca-certificates..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends curl bash ca-certificates
        rm -rf /var/lib/apt/lists/*
    else
        echo "Error: curl and bash are required and apt-get is not available to install them." >&2
        exit 1
    fi
fi

USER_NAME="${_REMOTE_USER:-root}"
if [ "${USER_NAME}" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="${_REMOTE_USER_HOME:-$(getent passwd "${USER_NAME}" | cut -d: -f6)}"
fi
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
    echo "Error: could not determine the home directory of user '${USER_NAME}'." >&2
    exit 1
fi

echo "Installing Claude Code (${CLAUDE_VERSION}) for user '${USER_NAME}'..."
INSTALLER=$(mktemp)
curl -sSfL "https://claude.ai/install.sh" -o "${INSTALLER}"
chmod 0644 "${INSTALLER}"
if [ "${USER_NAME}" = "root" ]; then
    bash "${INSTALLER}" "${CLAUDE_VERSION}"
else
    su -s /bin/bash - "${USER_NAME}" -c "bash '${INSTALLER}' '${CLAUDE_VERSION}'"
fi
rm -f "${INSTALLER}"

CLAUDE_BIN="${USER_HOME}/.local/bin/claude"
if [ ! -e "${CLAUDE_BIN}" ]; then
    echo "Error: Claude Code binary not found at ${CLAUDE_BIN} after installation." >&2
    exit 1
fi

# The installer only touches the user's shell profile; a symlink makes the CLI
# available on PATH for every shell (including non-login ones used by tests).
ln -sf "${CLAUDE_BIN}" /usr/local/bin/claude

if [ "${TEACHER_MODE}" = "true" ]; then
    echo "Applying mentor mode guardrails..."
    CLAUDE_DIR="${USER_HOME}/.claude"
    mkdir -p "${CLAUDE_DIR}/output-styles" "${CLAUDE_DIR}/hooks"

    install -m 0644 "${FEATURE_DIR}/assets/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md"
    install -m 0644 "${FEATURE_DIR}/assets/mentor.md" "${CLAUDE_DIR}/output-styles/mentor.md"
    install -m 0755 "${FEATURE_DIR}/assets/deny-file-edits.sh" "${CLAUDE_DIR}/hooks/deny-file-edits.sh"

    cat > "${CLAUDE_DIR}/settings.json" <<EOF
{
  "outputStyle": "Mentor",
  "permissions": {
    "deny": [
      "Edit",
      "Write",
      "NotebookEdit",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git merge:*)",
      "Bash(git apply:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr merge:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_DIR}/hooks/deny-file-edits.sh"
          }
        ]
      }
    ]
  }
}
EOF

    chown -R "${USER_NAME}:" "${CLAUDE_DIR}"
else
    echo "teacherMode is disabled; skipping mentor guardrails."
fi

echo "Validating the Claude Code installation..."
if "${CLAUDE_BIN}" --version >/dev/null 2>&1; then
    echo "Success: claude $("${CLAUDE_BIN}" --version) is ready!"
else
    echo "Error: failed to validate the Claude Code installation." >&2
    exit 1
fi

echo "Claude Code configured and validated!"
