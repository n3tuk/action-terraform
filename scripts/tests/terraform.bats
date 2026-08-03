#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "version extracts a stable Terraform version from terraform output" {
  load_common
  export MOCK_TERRAFORM_VERSION='Terraform v1.9.0\non linux_amd64'

  run version

  assert_success
  assert_output '1.9.0'
  assert_call terraform version
}

@test "version extracts prerelease Terraform versions" {
  load_common
  export MOCK_TERRAFORM_VERSION='Terraform v1.10.0-rc1\non linux_amd64'

  run version

  assert_success
  assert_output '1.10.0-rc1'
}

@test "version fails when Terraform emits no matching version" {
  load_common
  export MOCK_TERRAFORM_VERSION='not a Terraform version'

  run version

  assert_failure
  assert_output ''
}

@test "providers returns a valid sorted provider map using real hcledit" {
  load_common
  write_lockfile
  cd "${CONFIGURATION}"

  run providers

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/providers.json"
  run jq -e '."hashicorp/aws" == "5.0.0" and ."hashicorp/random" == "3.6.0"' "${TEST_ROOT}/providers.json"
  assert_success
  assert_output 'true'
}

@test "providers handles a lock file containing one provider" {
  load_common
  cat >"${CONFIGURATION}/.terraform.lock.hcl" <<'EOF'
provider "registry.terraform.io/hashicorp/null" {
  version = "3.2.2"
  hashes  = ["h1:example"]
}
EOF
  cd "${CONFIGURATION}"

  run providers

  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/providers.json"
  run jq -e 'keys == ["hashicorp/null"] and ."hashicorp/null" == "3.2.2"' "${TEST_ROOT}/providers.json"
  assert_success
  assert_output 'true'
}

@test "providers returns an empty object for an empty lock file" {
  load_common
  printf '' >"${CONFIGURATION}/.terraform.lock.hcl"
  cd "${CONFIGURATION}"

  run providers

  assert_success
  assert_output '{}'
}
