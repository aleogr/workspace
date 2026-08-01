#!/bin/sh
set -e

PYTHON_VERSION=${PYTHONVERSION:-"latest"}
INSTALL_RUFF=${INSTALLRUFF:-"true"}

INSTALL_DIR="/usr/local/python"
GROUP_NAME="python"

echo "Starting Python environment installation..."

if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing curl and ca-certificates..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends curl ca-certificates
        rm -rf /var/lib/apt/lists/*
    else
        echo "Error: curl is required and apt-get is not available to install it." >&2
        exit 1
    fi
fi

# uv resolves the version, downloads the matching standalone CPython build and
# verifies it, so this feature does not have to track release URLs itself.
echo "Installing uv..."
INSTALLER=$(mktemp)
curl -sSfL "https://astral.sh/uv/install.sh" -o "${INSTALLER}"
UV_INSTALL_DIR="/usr/local/bin" UV_NO_MODIFY_PATH=1 sh "${INSTALLER}"
rm -f "${INSTALLER}"

if [ ! -x /usr/local/bin/uv ]; then
    # Older installers ignore UV_INSTALL_DIR and fall back to the home directory.
    for CANDIDATE in "${HOME:-/root}/.local/bin/uv" /root/.local/bin/uv; do
        if [ -x "${CANDIDATE}" ]; then
            install -m 0755 "${CANDIDATE}" /usr/local/bin/uv
            break
        fi
    done
fi

if [ ! -x /usr/local/bin/uv ]; then
    echo "Error: uv was not installed to a usable location." >&2
    exit 1
fi

export PATH="/usr/local/bin:$PATH"
export UV_PYTHON_INSTALL_DIR="${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

echo "Installing Python (${PYTHON_VERSION})..."
if [ "${PYTHON_VERSION}" = "latest" ]; then
    uv python install
else
    uv python install "${PYTHON_VERSION}"
fi

# The install directory holds nothing but the interpreter uv just placed there,
# so picking the highest versioned bin/python3.x in it is unambiguous and does
# not depend on a system interpreter winning a version request. The trailing
# anchor matters: bin/ also holds python3.x-config, which sorts after the
# interpreter itself.
PYTHON_BIN=$(find "${INSTALL_DIR}" -type f -path '*/bin/python3.*' -perm -u+x \
    | grep -E '/python3\.[0-9]+$' \
    | sort -V \
    | tail -n 1)
if [ -z "${PYTHON_BIN}" ]; then
    echo "Error: no interpreter found under ${INSTALL_DIR} after installation." >&2
    exit 1
fi
PYTHON_DIR=$(dirname "${PYTHON_BIN}")
PYTHON_MINOR=$(basename "${PYTHON_BIN}")

# uv marks its interpreters PEP 668 externally managed, which makes a plain
# 'pip install' fail. In a dev container the container itself is the
# environment, so the marker is dropped to keep pip usable without a venv.
echo "Clearing the PEP 668 externally-managed marker..."
find "${INSTALL_DIR}" -name 'EXTERNALLY-MANAGED' -delete

if [ ! -x "${PYTHON_DIR}/pip" ]; then
    echo "Bootstrapping pip..."
    "${PYTHON_BIN}" -m ensurepip --upgrade >/dev/null
fi

if [ "${INSTALL_RUFF}" = "true" ]; then
    echo "Installing Ruff..."
    "${PYTHON_BIN}" -m pip install --no-cache-dir --disable-pip-version-check \
        --root-user-action=ignore --quiet ruff
else
    echo "installRuff is disabled; skipping Ruff."
fi

echo "Linking interpreter and tools into /usr/local/bin..."
ln -sf "${PYTHON_BIN}" "/usr/local/bin/${PYTHON_MINOR}"
ln -sf "${PYTHON_BIN}" /usr/local/bin/python3
ln -sf "${PYTHON_BIN}" /usr/local/bin/python
for TOOL in pip pip3 ruff; do
    if [ -x "${PYTHON_DIR}/${TOOL}" ]; then
        ln -sf "${PYTHON_DIR}/${TOOL}" "/usr/local/bin/${TOOL}"
    fi
done

# Installing packages outside a virtual environment writes into the interpreter's
# site-packages, so the dev user needs write access to it. Ownership cannot be
# used: the CLI may remap the remote user's UID after features run and only
# re-chowns their home directory, which would leave this tree behind under a
# stale UID. A named group survives that remap, and keeps the tree from having
# to be world writable.
USER_NAME="${_REMOTE_USER:-root}"
if [ "${USER_NAME}" != "root" ] && getent passwd "${USER_NAME}" >/dev/null 2>&1; then
    if command -v groupadd >/dev/null 2>&1 && command -v usermod >/dev/null 2>&1; then
        echo "Granting '${USER_NAME}' write access to ${INSTALL_DIR} via the '${GROUP_NAME}' group..."
        getent group "${GROUP_NAME}" >/dev/null 2>&1 || groupadd --system "${GROUP_NAME}"
        usermod -aG "${GROUP_NAME}" "${USER_NAME}"
        chgrp -R "${GROUP_NAME}" "${INSTALL_DIR}"
        chmod -R g+w "${INSTALL_DIR}"
        # setgid keeps newly installed packages in the group.
        find "${INSTALL_DIR}" -type d -exec chmod g+s {} +
    else
        echo "Warning: groupadd/usermod unavailable; ${INSTALL_DIR} stays root owned." >&2
    fi
fi

echo "Validating installed Python tools..."
if command -v python >/dev/null 2>&1 && command -v pip >/dev/null 2>&1 && command -v uv >/dev/null 2>&1; then
    echo "Success: $(python --version) is ready!"
    echo "Success: $(pip --version | awk '{print $1, $2}') is ready!"
    echo "Success: uv $(uv --version | awk '{print $2}') is ready!"
    if [ "${INSTALL_RUFF}" = "true" ]; then
        echo "Success: $(ruff --version) is ready!"
    fi
else
    echo "Error: failed to validate the Python environment installation." >&2
    exit 1
fi

echo "Python environment configured and validated!"
