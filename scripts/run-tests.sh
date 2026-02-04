#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTP="$ROOT"

run_test() {
  local module="$1"
  nvim --headless -u NONE "+set rtp+=${RTP}" "+lua require('${module}').run()" +q
}

if [ "${1-}" != "" ]; then
  run_test "$1"
  exit 0
fi

tests=()
while IFS= read -r test_file; do
  tests+=("$test_file")
done < <(find "$ROOT/lua/tests" -type f -name "*_test.lua" | sort)
if [ "${#tests[@]}" -eq 0 ]; then
  printf "No tests found\n"
  exit 1
fi

for file in "${tests[@]}"; do
  module="${file#${ROOT}/lua/}"
  module="${module%.lua}"
  module="${module//\//.}"
  printf "Running %s\n" "${module}"
  run_test "${module}"
done
