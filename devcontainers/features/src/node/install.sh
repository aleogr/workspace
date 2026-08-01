#!/bin/sh
set -e

NODE_VERSION=${NODEVERSION:-"lts"}
ENABLE_COREPACK=${ENABLECOREPACK:-"true"}

NODE_DIST="https://nodejs.org/dist"
INSTALL_DIR="/usr/local/node"
GROUP_NAME="nodejs"

echo "Starting Node.js environment installation..."

if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing curl, tar and ca-certificates..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends curl tar ca-certificates
        rm -rf /var/lib/apt/lists/*
    else
        echo "Error: curl and tar are required and apt-get is not available to install them." >&2
        exit 1
    fi
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

TMP_DIR=$(mktemp -d)

# The release index is newest first and holds one flat JSON object per release,
# so splitting on '}' yields one line per release. "lts" carries the codename on
# LTS lines and the literal false everywhere else. The index is read from a file
# because piping curl straight into 'head' makes curl abort mid transfer and
# report a write error.
resolve_version() {
    tr '}' '\n' < "${TMP_DIR}/index.json" \
        | grep "$1" \
        | head -n 1 \
        | sed -E 's/.*"version":"v([^"]+)".*/\1/'
}

case "${NODE_VERSION}" in
    lts|latest)
        echo "Resolving the newest '${NODE_VERSION}' Node.js release..."
        curl -sSfL "${NODE_DIST}/index.json" -o "${TMP_DIR}/index.json"
        if [ "${NODE_VERSION}" = "lts" ]; then
            NODE_VERSION=$(resolve_version '"lts":"')
        else
            NODE_VERSION=$(resolve_version '"version":"v')
        fi
        rm -f "${TMP_DIR}/index.json"
        ;;
    *)
        NODE_VERSION=${NODE_VERSION#v}
        ;;
esac

if [ -z "${NODE_VERSION}" ]; then
    echo "Error: could not resolve the requested Node.js version." >&2
    exit 1
fi
echo "Resolved Node.js version: ${NODE_VERSION}"

TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz"

echo "Downloading Node.js ${NODE_VERSION}..."
curl -sSfL "${NODE_DIST}/v${NODE_VERSION}/${TARBALL}" -o "${TMP_DIR}/${TARBALL}"

echo "Verifying the Node.js checksum..."
curl -sSfL "${NODE_DIST}/v${NODE_VERSION}/SHASUMS256.txt" -o "${TMP_DIR}/SHASUMS256.txt"
(cd "${TMP_DIR}" && grep "  ${TARBALL}\$" SHASUMS256.txt | sha256sum -c -)

echo "Installing Node.js into ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -C "${INSTALL_DIR}" --strip-components=1 -xzf "${TMP_DIR}/${TARBALL}"
rm -rf "${TMP_DIR}"

export PATH="${INSTALL_DIR}/bin:$PATH"

if [ "${ENABLE_COREPACK}" = "true" ]; then
    if command -v corepack >/dev/null 2>&1; then
        echo "Enabling Corepack (yarn and pnpm shims)..."
        corepack enable --install-directory "${INSTALL_DIR}/bin"
    else
        echo "Warning: Node.js ${NODE_VERSION} does not bundle Corepack; skipping." >&2
    fi
else
    echo "enableCorepack is disabled; skipping Corepack setup."
fi

# Global installs (npm install -g) write inside the prefix, so the dev user needs
# write access to it. Ownership cannot be used: the CLI may remap the remote
# user's UID after features run and only re-chowns their home directory, which
# would leave this tree behind under a stale UID. A named group survives that
# remap, and keeps the prefix from having to be world writable.
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

echo "Validating installed Node.js tools..."
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Success: node $(node --version) is ready!"
    echo "Success: npm $(npm --version) is ready!"
else
    echo "Error: failed to validate the Node.js environment installation." >&2
    exit 1
fi

echo "Node.js environment configured and validated!"
