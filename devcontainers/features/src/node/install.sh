#!/bin/sh
set -e

NODE_VERSION=${NODEVERSION:-"lts"}
ENABLE_COREPACK=${ENABLECOREPACK:-"true"}

NODE_DIST="https://nodejs.org/dist"
INSTALL_DIR="/usr/local/node"

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

# The release index is newest first and holds one flat JSON object per release,
# so splitting on '}' yields one line per release. "lts" carries the codename on
# LTS lines and the literal false everywhere else.
resolve_version() {
    curl -sSfL "${NODE_DIST}/index.json" \
        | tr '}' '\n' \
        | grep "$1" \
        | head -n 1 \
        | sed -E 's/.*"version":"v([^"]+)".*/\1/'
}

case "${NODE_VERSION}" in
    lts)
        echo "Resolving the latest Node.js LTS version..."
        NODE_VERSION=$(resolve_version '"lts":"')
        ;;
    latest)
        echo "Resolving the latest Node.js version..."
        NODE_VERSION=$(resolve_version '"version":"v')
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
TMP_DIR=$(mktemp -d)

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

# Global installs (npm install -g) write inside the prefix, so the dev user owns
# the tree instead of it being world writable.
USER_NAME="${_REMOTE_USER:-root}"
if [ "${USER_NAME}" != "root" ] && getent passwd "${USER_NAME}" >/dev/null 2>&1; then
    echo "Granting '${USER_NAME}' ownership of ${INSTALL_DIR}..."
    chown -R "${USER_NAME}:" "${INSTALL_DIR}"
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
