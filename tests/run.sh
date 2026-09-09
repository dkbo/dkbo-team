#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -x tests/lib/bats-core/bin/bats ]; then
  git clone -q --depth 1 https://github.com/bats-core/bats-core tests/lib/bats-core
fi
chmod +x tests/stub/herdr tests/stub/cli/* .dkbo/bin/* 2>/dev/null || true
exec tests/lib/bats-core/bin/bats "${@:-tests/unit}"
