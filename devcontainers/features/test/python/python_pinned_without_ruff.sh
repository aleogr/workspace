#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

# shellcheck disable=SC2016
check "pinned minor version" bash -c '[ "$(python -c "import sys; print(\"%d.%d\" % sys.version_info[:2])")" = "3.12" ]'
check "pip" pip --version
check "uv" uv --version
check "no ruff" bash -c '! command -v ruff'

reportResults
