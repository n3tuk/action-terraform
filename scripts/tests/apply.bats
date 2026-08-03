#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "apply warnings and errors return safe fallbacks for missing logs" {
  load_common
  cd "${CONFIGURATION}"

  run apply:warnings
  assert_success
  assert_output '[]'
  run apply:errors
  assert_success
  assert_output '["Terraform exited before starting the apply process, or no apply.log could be found"]'
}

@test "apply warnings and errors are sorted and deduplicated" {
  load_common
  write_log "${CONFIGURATION}/.terraform/apply.log" \
    'Warning: zeta warning' \
    'Warning: alpha warning' \
    'Warning: zeta warning' \
    'Error: zeta error' \
    'Error: alpha error' \
    'Error: zeta error'
  cd "${CONFIGURATION}"

  run apply:warnings
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/warnings.json"
  run jq -e '.[0] == "alpha warning" and .[1] == "zeta warning" and length == 2' "${TEST_ROOT}/warnings.json"
  assert_success
  assert_output 'true'

  run apply:errors
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/errors.json"
  run jq -e '.[0] == "alpha error" and .[1] == "zeta error" and length == 2' "${TEST_ROOT}/errors.json"
  assert_success
  assert_output 'true'
}

@test "apply changes parses resource counts from an apply completion line" {
  load_common
  write_apply_log "${CONFIGURATION}/.terraform/apply.log"
  cd "${CONFIGURATION}"

  run apply:changes

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/changes.json"
  run jq -e '.Added == 1 and .Changed == 2 and .Destroyed == 3' "${TEST_ROOT}/changes.json"
  assert_success
  assert_output 'true'
}

@test "apply changes return zero counts without a completion line" {
  load_common
  write_log "${CONFIGURATION}/.terraform/apply.log" 'Apply failed before completion'
  cd "${CONFIGURATION}"

  run apply:changes

  assert_success
  assert_output '{"Added": 0, "Changed": 0, "Destroyed": 0}'
}

@test "apply context produces valid JSON including partial changes" {
  load_common
  write_lockfile
  write_apply_log "${CONFIGURATION}/.terraform/apply.log"
  context="${TEST_ROOT}/apply-context.json"
  cd "${CONFIGURATION}"

  run apply:context "${context}" 1

  assert_success
  run jq -e '.Summary.ExitStatus == 1 and .Changes.Added == 1 and .Changes.Changed == 2 and .Changes.Destroyed == 3 and (.Warnings | length) == 1 and (.Errors | length) == 1' "${context}"
  assert_success
  assert_output 'true'
}

@test "apply response skips an absent status marker" {
  load_common
  cd "${CONFIGURATION}"
  context="${TEST_ROOT}/apply-context.json"

  run apply:response "${context}"

  assert_success
  assert_summary_not_written
}

@test "apply response renders a successful summary" {
  load_common
  write_lockfile
  write_apply_log "${CONFIGURATION}/.terraform/apply.log"
  printf '0' >"${CONFIGURATION}/.terraform/apply"
  context="${TEST_ROOT}/apply-context.json"
  cd "${CONFIGURATION}"

  run apply:response "${context}"

  assert_success
  assert_output --partial 'Terraform has applied the execution plan'
  assert_summary_contains '1 resources added, 2 changed, and 3 destroyed.'
}

@test "apply response renders a partial failed summary with warnings and errors" {
  load_common
  write_lockfile
  write_apply_log "${CONFIGURATION}/.terraform/apply.log"
  printf '1' >"${CONFIGURATION}/.terraform/apply"
  context="${TEST_ROOT}/apply-context.json"
  cd "${CONFIGURATION}"
  export CI=true

  run apply:response "${context}"

  assert_success
  assert_output --partial '::error title=terraform apply ./terraform/terraform.tfplan::Terraform failed to apply the execution plan for ./terraform.'
  assert_summary_contains 'partially failed'
  assert_summary_contains 'A partial apply error'
}

@test "apply no-plan template renders its no-plan guidance" {
  load_common
  context="${TEST_ROOT}/apply-no-plan.json"
  printf '{}' >"${context}"

  run output:template "${context}" terraform-apply-no-plan.md.t

  assert_success
  assert_output --partial 'terraform.tfplan file could not be found'
  assert_output --partial 'terraform was not run'
}

@test "apply orchestration calls switch then apply, cleans stale artifacts, and restores the caller directory" {
  load_common
  write_lockfile
  write_apply_log "${TEST_ROOT}/orchestration-apply.log"
  configure_task terraform:apply 0 "${TEST_ROOT}/orchestration-apply.log"
  printf stale >"${CONFIGURATION}/.terraform/apply.log"
  caller=${PWD}

  run apply

  assert_success
  assert_equal "${caller}" "${PWD}"
  assert_call terraform:switch
  assert_call terraform:apply
  assert_file_contains "${CONFIGURATION}/.terraform/apply" '0'
  assert_summary_contains 'Terraform has applied the execution plan'
}

@test "apply orchestration propagates failed apply and reports unpinned configuration" {
  load_common
  failure_log="${TEST_ROOT}/orchestration-apply-failure.log"
  write_apply_log "${failure_log}"
  configure_task terraform:apply 1 "${failure_log}"
  export CI=true

  run apply

  assert_failure
  assert_output --partial '::warning title=terraform init ./terraform::The Terraform configuration at ./terraform does not contain a .terraform.lock.hcl file'
  assert_output --partial '::error title=terraform apply ./terraform/terraform.tfplan::Terraform failed to apply the execution plan for ./terraform.'
  assert_summary_contains 'partially failed'
}
