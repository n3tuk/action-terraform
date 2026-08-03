#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

run_action() {
  run "${REPO_ROOT}/scripts/bin/run"
}

@test "run validates a configuration through the real entry point" {
  load_common
  write_lockfile
  export DEBUG=true

  run_action

  assert_success
  assert_output --partial 'TF_NAME = ./terraform'
  assert_output --partial 'Terraform has successfully initialised and validated'
  assert_call terraform:switch
  assert_call terraform:validate
  assert_file_contains "${MOCK_LOG}" 'env.TF_IN_AUTOMATION=true'
  assert_file_contains "${MOCK_LOG}" 'env.NO_COLOR=1'
  assert_file_contains "${MOCK_LOG}" 'env.TASK_OUTPUT=group'
}

@test "run validates module examples through the real entry point" {
  load_common
  export TF_MODULE=true
  mkdir -p "${CONFIGURATION}/examples/basic" "${CONFIGURATION}/examples/nested"
  printf 'resource "null_resource" "basic" {}\n' >"${CONFIGURATION}/examples/basic/main.tf"
  printf 'resource "null_resource" "nested" {}\n' >"${CONFIGURATION}/examples/nested/main.tf"
  write_lockfile "${CONFIGURATION}/examples/basic/.terraform.lock.hcl"
  write_lockfile "${CONFIGURATION}/examples/nested/.terraform.lock.hcl"

  run_action

  assert_success
  assert_output --partial 'Terraform has successfully initialised and validated the example module configuration(s)'
  assert_call_count task 4
  assert_file_contains "${GITHUB_STEP_SUMMARY}" 'examples/basic'
  assert_file_contains "${GITHUB_STEP_SUMMARY}" 'examples/nested'
}

@test "run plans through the real entry point and preserves normalized paths" {
  load_common
  export TF_ACTION=plan TF_CONFIGURATION=./terraform
  write_lockfile
  write_plan_log "${TEST_ROOT}/run-plan.log"
  configure_task terraform:plan 0 "${TEST_ROOT}/run-plan.log"
  export DEBUG=true

  run_action

  assert_success
  assert_output --partial 'TF_NAME = ./terraform'
  assert_output --partial 'Terraform has generated an execution plan'
  assert_call terraform:switch
  assert_call terraform:plan
  assert_file_contains "${CONFIGURATION}/terraform.tfplan" ''
}

@test "run applies through the real entry point" {
  load_common
  export TF_ACTION=apply
  write_lockfile
  write_apply_log "${TEST_ROOT}/run-apply.log"
  configure_task terraform:apply 0 "${TEST_ROOT}/run-apply.log"

  run_action

  assert_success
  assert_output --partial 'Terraform has applied the execution plan'
  assert_call terraform:switch
  assert_call terraform:apply
}

@test "run rejects an invalid action after command preflight" {
  load_common
  export TF_ACTION=destroy

  run_action

  assert_failure
  assert_output --partial 'terraform destroy is not a valid action'
  assert_no_call task
  assert_no_call terraform
}

@test "run requires action and workspace environment variables" {
  load_common
  run env -u TF_ACTION "${REPO_ROOT}/scripts/bin/run"
  assert_failure
  assert_output --partial 'TF_ACTION Not Found'

  run env -u GITHUB_WORKSPACE "${REPO_ROOT}/scripts/bin/run"
  assert_failure
  assert_output --partial 'GITHUB_WORKSPACE Not Found'
}

@test "run requires TF_MODULE only for validation" {
  load_common
  unset TF_MODULE

  run_action

  assert_failure
  assert_output --partial 'TF_MODULE Not Found'

  export TF_ACTION=plan
  write_lockfile
  write_plan_log "${TEST_ROOT}/run-plan-without-module.log"
  configure_task terraform:plan 0 "${TEST_ROOT}/run-plan-without-module.log"
  run_action
  assert_success
}

@test "run rejects a missing required executable before checking action inputs" {
  load_common
  rm "${MOCK_BIN}/task"

  run_action

  assert_failure
  assert_output --partial 'task Not Found'
  assert_no_call task
}

@test "run changes to GITHUB_WORKSPACE before invoking lifecycle tasks" {
  load_common
  write_lockfile
  outside="${TEST_ROOT}/outside"
  mkdir -p "${outside}"
  cd "${outside}"

  run_action

  assert_success
  assert_file_contains "${MOCK_LOG}" "cwd=${CONFIGURATION}"
}
