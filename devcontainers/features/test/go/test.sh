#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "go" go version
check "golangci-lint" golangci-lint --version
# shellcheck disable=SC2016
check "gopath is /go" bash -c '[ "$(go env GOPATH)" = "/go" ]'
check "gopath is writable" bash -c 'touch /go/bin/.write-test && rm /go/bin/.write-test'

reportResults
