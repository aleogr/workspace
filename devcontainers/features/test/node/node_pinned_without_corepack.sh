#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

# shellcheck disable=SC2016
check "pinned node version" bash -c '[ "$(node --version)" = "v22.11.0" ]'
check "npm" npm --version
check "no yarn shim" bash -c '! test -e /usr/local/node/bin/yarn'
check "no pnpm shim" bash -c '! test -e /usr/local/node/bin/pnpm'

reportResults
