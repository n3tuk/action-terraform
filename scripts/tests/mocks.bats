#!/usr/bin/env bats

load 'helpers/load'
load_helpers

@test "strict command mocks preserve argument boundaries and configurable status" {
  load_common
  configure_task terraform:plan 7
  cd "${CONFIGURATION}"

  run task terraform:plan

  assert_failure 7
  assert_call task terraform:plan
  assert_file_contains '.terraform/plan' '7'
}

@test "tfswitch mock records exact arguments without network access" {
  load_common
  switch_bin="${CONFIGURATION}/.bin/terraform"

  run tfswitch --bin "${switch_bin}"

  assert_success
  assert_call tfswitch --bin "${switch_bin}"
}

@test "terraform mock provides realistic version output and rejects unexpected subcommands" {
  load_common
  export MOCK_TERRAFORM_VERSION='Terraform v1.8.5'

  run terraform version
  assert_success
  assert_output 'Terraform v1.8.5'
  assert_call terraform version

  run terraform apply plan.tfplan
  assert_failure 98
  assert_output --partial 'unexpected terraform subcommand: apply'
}
