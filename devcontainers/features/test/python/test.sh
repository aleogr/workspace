#!/bin/bash
set -e

# shellcheck disable=SC1091
source dev-container-features-test-lib

check "python" python --version
check "python3" python3 --version
check "pip" pip --version
check "uv" uv --version
check "ruff" ruff --version
# Standalone builds are easy to ship without their optional C extensions, so the
# modules that need one are imported explicitly.
check "stdlib C extensions" python -c 'import ssl, sqlite3, zlib, lzma, ctypes'
check "venv works" bash -c 'python -m venv /tmp/venv-test && /tmp/venv-test/bin/python --version && rm -rf /tmp/venv-test'
# uv ships its interpreters as PEP 668 externally managed, which would make a
# plain 'pip install' fail; the feature clears that on purpose.
check "pip is not externally managed" python -c 'import os, sys, sysconfig; sys.exit(os.path.exists(os.path.join(sysconfig.get_path("stdlib"), "EXTERNALLY-MANAGED")))'
check "user is in the python group" bash -c 'id -nG | tr " " "\n" | grep -qx python'
# shellcheck disable=SC2016
check "site-packages is writable" bash -c 'sp=$(python -c "import site; print(site.getsitepackages()[0])") && touch "$sp/.write-test" && rm "$sp/.write-test"'
# shellcheck disable=SC2016
check "install dir is not world writable" bash -c '[ "$(stat -c %A /usr/local/python | cut -c9)" = "-" ]'

reportResults
