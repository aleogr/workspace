#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "container builds with the metadata-only feature" true

reportResults
