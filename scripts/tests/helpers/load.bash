#!/usr/bin/env bash

export BATS_LIB_PATH="${BATS_LIB_PATH:-/usr/lib/bats}"

load_helpers() {
  local helper_root
  local -a helper_roots
  IFS=: read -ra helper_roots <<<"${BATS_LIB_PATH}"
  for helper_root in "${helper_roots[@]}"; do
    if [[ -f "${helper_root}/bats-support/load.bash" ]]; then
      bats_load_library "${helper_root}/bats-support/load.bash"
      bats_load_library "${helper_root}/bats-assert/load.bash"
      bats_load_library "${helper_root}/bats-file/load.bash"
      load 'helpers/setup'
      load 'helpers/assertions'
      load 'helpers/fixtures'
      return 0
    fi
  done
  printf 'BATS helper libraries were not found in BATS_LIB_PATH=%s\n' "${BATS_LIB_PATH}" >&2
  return 1
}
