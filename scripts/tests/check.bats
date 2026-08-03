#!/usr/bin/env bats

load 'helpers/load'
load_helpers

@test "check:path normalizes default and root references" {
  load_common

  assert_equal "${GITHUB_WORKSPACE}" "$(check:path)"
  assert_equal "${GITHUB_WORKSPACE}" "$(check:path .)"
  assert_equal "${GITHUB_WORKSPACE}" "$(check:path ./)"
  assert_equal "${GITHUB_WORKSPACE}" "$(check:path /)"
}

@test "check:path resolves relative, dot-relative, absolute, and spaced paths" {
  load_common

  assert_equal "${GITHUB_WORKSPACE}/terraform/module" "$(check:path terraform/module)"
  assert_equal "${GITHUB_WORKSPACE}/terraform/module" "$(check:path ./terraform/module)"
  assert_equal "${GITHUB_WORKSPACE}/terraform/module" "$(check:path /terraform/module)"
  assert_equal "${GITHUB_WORKSPACE}/path with spaces" "$(check:path 'path with spaces')"
}

@test "check:name normalizes display names" {
  load_common

  assert_equal '.' "$(check:name)"
  assert_equal '.' "$(check:name .)"
  assert_equal '.' "$(check:name ./)"
  assert_equal '.' "$(check:name /)"
  assert_equal './terraform/module' "$(check:name terraform/module)"
  assert_equal './terraform/module' "$(check:name ./terraform/module)"
  assert_equal './terraform/module' "$(check:name /terraform/module)"
  assert_equal './path with spaces' "$(check:name 'path with spaces')"
}

@test "check:variable reports a populated variable" {
  load_common
  export CHECK_VALUE=value

  run check:variable CHECK_VALUE

  assert_success
  assert_output --partial 'CHECK_VALUE = value'
}

@test "check:variable reports sensitive variables without their value" {
  load_common
  export CHECK_SECRET=super-secret

  run check:variable CHECK_SECRET:sensitive

  assert_success
  assert_output --partial 'CHECK_SECRET exists'
  refute_output --partial 'super-secret'
}

@test "check:variable exits with an error for an unset variable" {
  run bash -c 'export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; unset MISSING_VALUE; check:variable MISSING_VALUE'

  assert_failure
  assert_output --partial 'MISSING_VALUE Not Found'
}

@test "check:variables stops at the first missing variable" {
  run bash -c 'export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; export PRESENT=value; unset MISSING_VALUE; check:variables PRESENT MISSING_VALUE NEVER_REACHED'

  assert_failure
  assert_output --partial 'MISSING_VALUE Not Found'
  refute_output --partial 'NEVER_REACHED'
}

@test "check:command accepts an executable command" {
  load_common
  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/executable"
  chmod +x "${MOCK_BIN}/executable"

  run check:command executable

  assert_success
}

@test "check:command rejects missing and non-executable commands" {
  load_common

  run bash -c 'export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; check:command command-that-does-not-exist'
  assert_failure
  assert_output --partial 'command-that-does-not-exist Not Found'

  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/not-executable"
  chmod 644 "${MOCK_BIN}/not-executable"
  run bash -c 'export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; check:command not-executable'
  assert_failure
  assert_output --partial 'not-executable Not Found'
}

@test "exit:error emits an error and returns one" {
  run bash -c 'export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; exit:error "Title" "Details"'

  assert_failure
  assert_output --partial 'Title'
  assert_output --partial 'Details'
}
