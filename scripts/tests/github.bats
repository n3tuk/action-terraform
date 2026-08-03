#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "github group start and end emit CI group commands and a stage" {
  load_common
  export CI=true

  run github:group:start 'Terraform plan'
  assert_success
  assert_output --partial '::group::Terraform plan'
  assert_output --partial '==>'

  run github:group:end
  assert_success
  assert_output '::endgroup::'
}

@test "github group output is local-only when CI is disabled" {
  load_common
  export CI=false

  run github:group:start 'Terraform plan'
  assert_success
  refute_output --partial '::group::'
  assert_output --partial 'Terraform plan'

  run github:group:end
  assert_success
  refute_output --partial '::endgroup::'
}

@test "github:path appends the exact path command value" {
  load_common
  export GITHUB_PATH="${TEST_ROOT}/path-file"

  run github:path '/opt/terraform/bin'

  assert_success
  assert_equal '/opt/terraform/bin' "$(<"${GITHUB_PATH}")"
}

@test "github:output appends the exact output assignment" {
  load_common
  export GITHUB_OUTPUT="${TEST_ROOT}/output-file"

  run github:output result 'value with spaces'

  assert_success
  assert_equal 'result=value with spaces' "$(<"${GITHUB_OUTPUT}")"
}

@test "github path and output safely discard values when destinations are absent" {
  load_common
  unset GITHUB_PATH GITHUB_OUTPUT

  run github:path ignored
  assert_success
  run github:output ignored value
  assert_success
}
