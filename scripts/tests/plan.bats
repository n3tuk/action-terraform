#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "plan warnings and errors return safe fallbacks for missing logs" {
  load_common
  cd "${CONFIGURATION}"

  run plan:warnings
  assert_success
  assert_output '[]'
  run plan:errors
  assert_success
  assert_output '["Terraform exited before starting the plan process, or no plan.log could be found"]'
}

@test "plan warnings and errors are sorted and deduplicated" {
  load_common
  write_log "${CONFIGURATION}/.terraform/plan.log" \
    'Warning: zeta warning' \
    'Warning: alpha warning' \
    'Warning: zeta warning' \
    'Error: zeta error' \
    'Error: alpha error' \
    'Error: zeta error'
  cd "${CONFIGURATION}"

  run plan:warnings
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/warnings.json"
  run jq -e '.[0] == "alpha warning" and .[1] == "zeta warning" and length == 2' "${TEST_ROOT}/warnings.json"
  assert_success
  assert_output 'true'

  run plan:errors
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/errors.json"
  run jq -e '.[0] == "alpha error" and .[1] == "zeta error" and length == 2' "${TEST_ROOT}/errors.json"
  assert_success
  assert_output 'true'
}

@test "plan changes parses import and resource counts" {
  load_common
  write_log "${CONFIGURATION}/.terraform/plan.log" 'Plan: 2 to import, 3 to add, 4 to change, 5 to destroy.'
  cd "${CONFIGURATION}"

  run plan:changes

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/changes.json"
  run jq -e '.Import == 2 and .Add == 3 and .Change == 4 and .Destroy == 5' "${TEST_ROOT}/changes.json"
  assert_success
  assert_output 'true'
}

@test "plan changes return zero counts when no plan summary exists" {
  load_common
  write_log "${CONFIGURATION}/.terraform/plan.log" 'Planning failed. Terraform could not build a plan.'
  cd "${CONFIGURATION}"

  run plan:changes

  assert_success
  assert_output '{"Add": 0, "Change": 0, "Destroy": 0}'
}

@test "plan resources and data sources count refresh and read lines" {
  load_common
  write_log "${CONFIGURATION}/.terraform/plan.log" \
    'aws_instance.one: Refreshing state... [id=one]' \
    'aws_instance.two: Refreshing state... [id=two]' \
    'data.aws_caller_identity.current: Reading...' \
    'data.aws_region.current: Reading...'
  cd "${CONFIGURATION}"

  run plan:resources
  assert_success
  assert_output '2'
  run plan:sources
  assert_success
  assert_output '2'
}

@test "plan trim keeps Terraform plan content and removes leading refreshes and trailing separators" {
  load_common
  write_plan_log "${CONFIGURATION}/.terraform/plan.log"
  cd "${CONFIGURATION}"

  run plan:trim

  assert_success
  assert_file_contains '.terraform/plan.trimmed.log' 'Terraform used the selected providers'
  assert_file_contains '.terraform/plan.trimmed.log' 'Plan: 1 to add, 2 to change, 3 to destroy.'
  assert_file_not_contains '.terraform/plan.trimmed.log' 'Refreshing state'
  assert_file_not_contains '.terraform/plan.trimmed.log' 'Note:'
}

@test "plan trim preserves an indented Terraform error" {
  load_common
  write_log "${CONFIGURATION}/.terraform/plan.log" \
    'Terraform used the selected providers' \
    '  Error: Invalid plan input' \
    'Planning failed'
  cd "${CONFIGURATION}"

  run plan:trim

  assert_success
  assert_file_contains '.terraform/plan.trimmed.log' 'Error: Invalid plan input'
}

@test "plan trim warns but succeeds when the log is absent" {
  load_common
  cd "${CONFIGURATION}"

  run plan:trim

  assert_success
  assert_output --partial 'Plan Log Not Found'
}

@test "plan context produces valid JSON with counts and diagnostics" {
  load_common
  write_lockfile
  write_plan_log "${CONFIGURATION}/.terraform/plan.log"
  context="${TEST_ROOT}/plan-context.json"
  cd "${CONFIGURATION}"

  run plan:context "${context}" 0

  assert_success
  run jq -e '.Summary.ExitStatus == 0 and .Summary.Resources == 1 and .Summary.DataSources == 1 and .Changes.Add == 1 and .Changes.Change == 2 and .Changes.Destroy == 3 and (.Warnings | length) == 1' "${context}"
  assert_success
  assert_output 'true'
}

@test "plan response skips an absent status marker" {
  load_common
  cd "${CONFIGURATION}"
  context="${TEST_ROOT}/plan-context.json"

  run plan:response "${context}"

  assert_success
  assert_summary_not_written
}

@test "plan response renders a successful plan summary" {
  load_common
  write_lockfile
  write_plan_log "${CONFIGURATION}/.terraform/plan.log"
  printf '0' >"${CONFIGURATION}/.terraform/plan"
  context="${TEST_ROOT}/plan-context.json"
  cd "${CONFIGURATION}"

  run plan:response "${context}"

  assert_success
  assert_output --partial 'Terraform has built the execution plan'
  assert_summary_contains '1 resources processed'
  assert_summary_contains 'Plan: 1 to add'
}

@test "plan response renders a failed plan summary with errors" {
  load_common
  write_lockfile
  write_plan_log "${CONFIGURATION}/.terraform/plan.log"
  printf '1' >"${CONFIGURATION}/.terraform/plan"
  context="${TEST_ROOT}/plan-context.json"
  cd "${CONFIGURATION}"
  export CI=true

  run plan:response "${context}"

  assert_success
  assert_output --partial '::error title=terraform plan ./terraform::Terraform failed to build the execution plan for ./terraform.'
  assert_summary_contains 'terraform plan'
  assert_summary_contains 'Deprecated argument'
}

@test "plan orchestration calls switch then plan, cleans stale artifacts, and restores the caller directory" {
  load_common
  write_lockfile
  write_plan_log "${TEST_ROOT}/orchestration-plan.log"
  configure_task terraform:plan 0 "${TEST_ROOT}/orchestration-plan.log"
  printf stale >"${CONFIGURATION}/.terraform/plan.trimmed.log"
  caller=${PWD}

  run plan

  assert_success
  assert_equal "${caller}" "${PWD}"
  assert_call terraform:switch
  assert_call terraform:plan
  assert_file_contains "${CONFIGURATION}/.terraform/plan" '0'
  assert_summary_contains 'Terraform has generated an execution plan'
}

@test "plan orchestration propagates a failed plan and warning for an unpinned configuration" {
  load_common
  failure_log="${TEST_ROOT}/orchestration-plan-failure.log"
  write_plan_log "${failure_log}"
  configure_task terraform:plan 1 "${failure_log}"
  export CI=true

  run plan

  assert_failure
  assert_output --partial '::warning title=terraform init ./terraform::The Terraform configuration at ./terraform does not contain a .terraform.lock.hcl file'
  assert_output --partial '::error title=terraform plan ./terraform::Terraform failed to build the execution plan for ./terraform.'
  assert_summary_contains 'Terraform has generated an execution plan'
}
