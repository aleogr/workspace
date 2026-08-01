#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "node" node --version
check "npm" npm --version
check "npx" npx --version
check "node executes code" node -e 'process.exit(0)'
check "corepack" corepack --version
# The shims are only checked for presence: running them makes Corepack download
# a package manager, which needs a project pin and an interactive prompt.
check "yarn shim" test -x /usr/local/node/bin/yarn
check "pnpm shim" test -x /usr/local/node/bin/pnpm
# shellcheck disable=SC2016
check "default is an lts release" bash -c '[ "$(node -p "process.release.lts ? 1 : 0")" = "1" ]'
check "user is in the nodejs group" bash -c 'id -nG | tr " " "\n" | grep -qx nodejs'
check "prefix is writable" bash -c 'touch /usr/local/node/bin/.write-test && rm /usr/local/node/bin/.write-test'
# shellcheck disable=SC2016
check "prefix is not world writable" bash -c '[ "$(stat -c %A /usr/local/node/bin | cut -c9)" = "-" ]'

reportResults
