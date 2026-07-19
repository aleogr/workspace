#!/bin/sh
set -e

GORELEASER_VERSION=${GORELEASERVERSION:-"latest"}
INSTALL_BUILD_TOOLS=${INSTALLBUILDTOOLS:-"true"}

echo "Starting base environment installation..."

if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: this feature requires a Debian/Ubuntu based image (apt-get not found)." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Installing core system packages..."
apt-get update
apt-get install -y --no-install-recommends curl tar git ca-certificates jq

if [ "${INSTALL_BUILD_TOOLS}" = "true" ]; then
    echo "Installing build tools (build-essential)..."
    apt-get install -y --no-install-recommends build-essential
fi

rm -rf /var/lib/apt/lists/*

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) RELEASER_ARCH="x86_64" ;;
    aarch64|arm64) RELEASER_ARCH="arm64" ;;
    *) echo "Unsupported architecture for GoReleaser: $ARCH" >&2; exit 1 ;;
esac

if [ "${GORELEASER_VERSION}" = "latest" ]; then
    echo "Resolving the latest GoReleaser version..."
    GORELEASER_VERSION=$(curl -sSfLo /dev/null -w '%{url_effective}' "https://github.com/goreleaser/goreleaser/releases/latest")
    GORELEASER_VERSION=${GORELEASER_VERSION##*/}
    echo "Resolved GoReleaser version: ${GORELEASER_VERSION}"
fi

TARBALL="goreleaser_Linux_${RELEASER_ARCH}.tar.gz"
TMP_DIR=$(mktemp -d)

echo "Downloading GoReleaser ${GORELEASER_VERSION}..."
curl -sSfL "https://github.com/goreleaser/goreleaser/releases/download/${GORELEASER_VERSION}/${TARBALL}" -o "${TMP_DIR}/${TARBALL}"

echo "Verifying the GoReleaser checksum..."
curl -sSfL "https://github.com/goreleaser/goreleaser/releases/download/${GORELEASER_VERSION}/checksums.txt" -o "${TMP_DIR}/checksums.txt"
(cd "${TMP_DIR}" && grep "  ${TARBALL}\$" checksums.txt | sha256sum -c -)

tar -C /usr/local/bin -xzf "${TMP_DIR}/${TARBALL}" goreleaser
rm -rf "${TMP_DIR}"

echo "Validating installed base tools..."
if command -v curl >/dev/null 2>&1 && command -v git >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v goreleaser >/dev/null 2>&1; then
    echo "Success: git version $(git --version | awk '{print $3}') is ready!"
    echo "Success: jq version $(jq --version) is ready!"
    echo "Success: $(goreleaser --version | head -n 1) is ready!"
else
    echo "Error: failed to validate the base utilities installation." >&2
    exit 1
fi

echo "Base environment configured and validated!"
