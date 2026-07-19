#!/bin/sh
set -e

GO_VERSION=${GOVERSION:-"latest"}
LINT_VERSION=${LINTVERSION:-"latest"}
LINT_FALLBACK_VERSION="v2.12.2"

echo "Starting Go environment installation..."

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
    x86_64) GO_ARCH="amd64" ;;
    aarch64|arm64) GO_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

if [ "${GO_VERSION}" = "latest" ]; then
    echo "Resolving the latest stable Go version..."
    GO_VERSION=$(curl -sSfL "https://go.dev/dl/?mode=json" | grep -o '"version": "go[^"]*"' | head -n 1 | sed -E 's/.*"go([^"]+)".*/\1/')
    if [ -z "${GO_VERSION}" ]; then
        echo "Error: could not resolve the latest Go version." >&2
        exit 1
    fi
    echo "Resolved Go version: ${GO_VERSION}"
fi

TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
TMP_DIR=$(mktemp -d)

echo "Downloading Go ${GO_VERSION}..."
curl -sSfL "https://dl.google.com/go/${TARBALL}" -o "${TMP_DIR}/${TARBALL}"

echo "Verifying the Go checksum..."
EXPECTED_SHA=$(curl -sSfL "https://dl.google.com/go/${TARBALL}.sha256" | awk '{print $1}')
if [ -z "${EXPECTED_SHA}" ]; then
    echo "Error: could not fetch the checksum for ${TARBALL}." >&2
    exit 1
fi
echo "${EXPECTED_SHA}  ${TMP_DIR}/${TARBALL}" | sha256sum -c -

rm -rf /usr/local/go
tar -C /usr/local -xzf "${TMP_DIR}/${TARBALL}"
rm -rf "${TMP_DIR}"

echo "Preparing GOPATH at /go..."
mkdir -p /go/bin /go/src /go/pkg
chmod -R 777 /go

if [ "${LINT_VERSION}" = "latest" ]; then
    echo "Resolving the latest golangci-lint version..."
    LINT_VERSION=$(curl -sSfLo /dev/null -w '%{url_effective}' "https://github.com/golangci/golangci-lint/releases/latest")
    LINT_VERSION=${LINT_VERSION##*/}
    if [ -z "${LINT_VERSION}" ] || [ "${LINT_VERSION}" = "latest" ]; then
        echo "Warning: dynamic resolution failed. Using fallback version ${LINT_FALLBACK_VERSION}."
        LINT_VERSION="${LINT_FALLBACK_VERSION}"
    fi
    echo "Resolved golangci-lint version: ${LINT_VERSION}"
fi

echo "Installing golangci-lint ${LINT_VERSION}..."
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/${LINT_VERSION}/install.sh" | sh -s -- -b /usr/local/bin "${LINT_VERSION}"

echo "Validating installed Go tools..."
export PATH="/usr/local/go/bin:/go/bin:$PATH"

if command -v go >/dev/null 2>&1 && command -v golangci-lint >/dev/null 2>&1; then
    echo "Success: $(go version) is ready!"
    echo "Success: $(golangci-lint --version) is ready!"
else
    echo "Error: failed to validate the Go environment installation." >&2
    exit 1
fi

echo "Go environment configured and validated!"
