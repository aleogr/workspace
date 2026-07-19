#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "curl" curl --version
check "git" git --version
check "jq" jq --version
check "goreleaser" goreleaser --version

reportResults
