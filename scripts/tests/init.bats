#!/usr/bin/env bats

load 'helpers/load'
load_helpers

@test "init warnings are empty when the log is missing" {
  load_common
  cd "${CONFIGURATION}"

  run init:warnings

  assert_success
  assert_output '[]'
}

@test "init warnings are sorted and deduplicated" {
  load_common
  write_log "${CONFIGURATION}/.terraform/init.log" \
    'Warning: zeta warning' \
    'Warning: alpha warning' \
    'Warning: zeta warning'
  cd "${CONFIGURATION}"

  run init:warnings

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/warnings.json"
  run jq -e '.[0] == "alpha warning" and .[1] == "zeta warning" and length == 2' "${TEST_ROOT}/warnings.json"
  assert_success
  assert_output 'true'
}

@test "init warnings return an empty JSON array for a readable log with no warnings" {
  load_common
  write_log "${CONFIGURATION}/.terraform/init.log" 'Initializing the backend...'
  cd "${CONFIGURATION}"

  run init:warnings

  assert_success
  assert_output '[]'
}

@test "init errors use the missing-log fallback" {
  load_common
  cd "${CONFIGURATION}"

  run init:errors

  assert_success
  assert_output '["Terraform exited before initialising the configuration, or no init.log could be found"]'
}

@test "init errors filter the generic initialization message and deduplicate" {
  load_common
  write_log "${CONFIGURATION}/.terraform/init.log" \
    'Error: zeta error' \
    'Error: Terraform encountered problems during initialisation' \
    'Error: alpha error' \
    'Error: zeta error'
  cd "${CONFIGURATION}"

  run init:errors

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/errors.json"
  run jq -e '.[0] == "alpha error" and .[1] == "zeta error" and length == 2' "${TEST_ROOT}/errors.json"
  assert_success
  assert_output 'true'
}

@test "init errors return an empty JSON array for a readable log with no errors" {
  load_common
  write_log "${CONFIGURATION}/.terraform/init.log" 'Initialization completed'
  cd "${CONFIGURATION}"

  run init:errors

  assert_success
  assert_output '[]'
}

@test "init context produces valid metadata and parsed messages" {
  load_common
  write_lockfile
  write_init_log "${CONFIGURATION}/.terraform/init.log"
  context="${TEST_ROOT}/init-context.json"
  cd "${CONFIGURATION}"

  run init:context "${context}" 17

  assert_success
  run jq -e '.Summary.ExitStatus == 17 and .Summary.Resources == 0 and .Summary.DataSources == 0 and (.Warnings | length) == 1 and (.Errors | length) == 1 and .Changes.Add == 0' "${context}"
  assert_success
  assert_output 'true'
}

@test "init response skips missing and successful status markers" {
  load_common
  cd "${CONFIGURATION}"
  context="${TEST_ROOT}/unused.json"

  run init:response "${context}"
  assert_success
  assert_summary_not_written

  printf '0' >.terraform/init
  run init:response "${context}"
  assert_success
  assert_summary_not_written
}

@test "init response reports failures with an exact GitHub error and rendered summary" {
  load_common
  write_lockfile
  write_init_log "${CONFIGURATION}/.terraform/init.log"
  printf '1' >"${CONFIGURATION}/.terraform/init"
  context="${TEST_ROOT}/init-context.json"
  cd "${CONFIGURATION}"
  export CI=true

  run init:response "${context}"

  assert_success
  assert_output --partial '::error title=terraform init ./terraform::Terraform failed to initialise the configuration at ./terraform.'
  assert_summary_contains 'terraform init'
  assert_summary_contains 'Provider configuration error'
  run jq -e '.Summary.ExitStatus == 1' "${context}"
  assert_success
  assert_output 'true'
}
