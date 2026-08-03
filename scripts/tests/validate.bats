#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "validate warnings and errors use empty arrays for missing logs" {
  load_common
  cd "${CONFIGURATION}"

  run validate:warnings
  assert_success
  assert_output '[]'
  run validate:errors
  assert_success
  assert_output '["Terraform exited before starting the validate process, or no validate.log could be found"]'
}

@test "validate warnings and errors are sorted and deduplicated" {
  load_common
  write_validate_log "${CONFIGURATION}/.terraform/validate.log"
  cd "${CONFIGURATION}"

  run validate:warnings
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/warnings.json"
  run jq -e '.[0] == "Deprecated argument" and length == 1' "${TEST_ROOT}/warnings.json"
  assert_success
  assert_output 'true'

  run validate:errors
  assert_success
  printf '%s' "${output}" >"${TEST_ROOT}/errors.json"
  run jq -e '.[0] == "Invalid configuration" and length == 1' "${TEST_ROOT}/errors.json"
  assert_success
  assert_output 'true'
}

@test "validate context includes version providers and diagnostics" {
  load_common
  write_lockfile
  write_validate_log "${CONFIGURATION}/.terraform/validate.log"
  context="${TEST_ROOT}/validate-context.json"
  cd "${CONFIGURATION}"

  run validate:context "${context}" 1

  assert_success
  run jq -e '.Summary.ExitStatus == 1 and .Summary.Terraform == "1.9.0" and .Summary.Providers["hashicorp/aws"] == "5.0.0" and (.Warnings | length) == 1 and (.Errors | length) == 1' "${context}"
  assert_success
  assert_output 'true'
}

@test "validate response skips an absent status marker" {
  load_common
  cd "${CONFIGURATION}"
  context="${TEST_ROOT}/validate-context.json"

  run validate:response "${context}"

  assert_success
  assert_summary_not_written
}

@test "validate response renders a successful configuration summary" {
  load_common
  write_lockfile
  write_log "${CONFIGURATION}/.terraform/validate.log" 'Success! The configuration is valid.'
  printf '0' >"${CONFIGURATION}/.terraform/validate"
  context="${TEST_ROOT}/validate-context.json"
  cd "${CONFIGURATION}"

  run validate:response "${context}"

  assert_success
  assert_output --partial 'Terraform has successfully initialised and validated'
  assert_summary_contains 'terraform validate'
  run jq -e '.Summary.ExitStatus == 0' "${context}"
  assert_success
  assert_output 'true'
}

@test "validate response renders a failed configuration summary" {
  load_common
  write_lockfile
  write_validate_log "${CONFIGURATION}/.terraform/validate.log"
  printf '1' >"${CONFIGURATION}/.terraform/validate"
  context="${TEST_ROOT}/validate-context.json"
  cd "${CONFIGURATION}"
  export CI=true

  run validate:response "${context}"

  assert_success
  assert_output --partial '::error title=terraform validate ./terraform::Terraform failed to validate the configuration at ./terraform.'
  assert_summary_contains 'Invalid configuration'
}

@test "validate discover returns unique sorted example configurations" {
  load_common
  mkdir -p "${CONFIGURATION}/examples/zeta" "${CONFIGURATION}/examples/alpha/nested" "${CONFIGURATION}/examples/path with spaces"
  printf 'resource "null_resource" "one" {}\n' >"${CONFIGURATION}/examples/zeta/main.tf"
  printf 'resource "null_resource" "two" {}\n' >"${CONFIGURATION}/examples/zeta/second.tf"
  printf 'resource "null_resource" "three" {}\n' >"${CONFIGURATION}/examples/alpha/nested/main.tf"
  printf 'resource "null_resource" "four" {}\n' >"${CONFIGURATION}/examples/path with spaces/main.tf"
  printf 'not terraform\n' >"${CONFIGURATION}/examples/ignored.txt"

  run validate:discover

  assert_success
  assert_output "terraform/examples/alpha/nested\nterraform/examples/path with spaces\nterraform/examples/zeta"
}

@test "validate discover is empty when examples are absent" {
  load_common

  run validate:discover

  assert_success
  assert_output ''
}

@test "validate configuration runs switch and validate, restores the caller directory, and exports backend mode" {
  load_common
  write_lockfile
  log_file="${TEST_ROOT}/validate.log"
  write_log "${log_file}" 'Terraform validation passed'
  configure_task terraform:validate 0 "${log_file}"
  caller=${PWD}

  run validate:configuration

  assert_success
  assert_equal "${caller}" "${PWD}"
  assert_file_contains "${MOCK_LOG}" 'env.TF_BACKEND=false'
  assert_call terraform:switch
  assert_call terraform:validate
  assert_summary_contains 'Terraform has successfully initialised and validated'
}

@test "validate configuration propagates a validation failure and cleans stale artifacts" {
  load_common
  write_lockfile
  printf 'stale' >"${CONFIGURATION}/.terraform/validate.log"
  printf 'stale' >"${CONFIGURATION}/.terraform/init"
  log_file="${TEST_ROOT}/validate-failure.log"
  write_validate_log "${log_file}"
  configure_task terraform:validate 1 "${log_file}"
  export CI=true

  run validate:configuration

  assert_failure
  assert_output --partial '::error title=terraform validate ./terraform::Terraform failed to validate the configuration at ./terraform.'
  assert_file_contains "${CONFIGURATION}/.terraform/validate" '1'
  assert_summary_contains 'Invalid configuration'
}

@test "validate dispatches to configuration mode unless TF_MODULE is exactly true" {
  load_common
  write_lockfile
  configure_task terraform:validate 0
  export TF_MODULE=false

  run validate

  assert_success
  assert_call terraform:validate
}

@test "validate module reports missing examples with a rendered summary" {
  load_common
  export TF_MODULE=true TF_NAME=./terraform TF_PATH="${CONFIGURATION}"

  run validate:module

  assert_failure
  assert_output --partial 'No Terraform example configurations were found'
  assert_summary_contains 'no example configurations could be found'
}

@test "validate module validates all examples and aggregates failures" {
  load_common
  export TF_MODULE=true TF_NAME=./terraform TF_PATH="${CONFIGURATION}"
  mkdir -p "${CONFIGURATION}/examples/one" "${CONFIGURATION}/examples/two"
  printf 'resource "null_resource" "one" {}\n' >"${CONFIGURATION}/examples/one/main.tf"
  printf 'resource "null_resource" "two" {}\n' >"${CONFIGURATION}/examples/two/main.tf"
  write_lockfile "${CONFIGURATION}/examples/one/.terraform.lock.hcl"
  write_lockfile "${CONFIGURATION}/examples/two/.terraform.lock.hcl"
  success_log="${TEST_ROOT}/module-success.log"
  failure_log="${TEST_ROOT}/module-failure.log"
  write_log "${success_log}" 'Example one is valid'
  write_validate_log "${failure_log}"
  configure_task terraform:validate 1 "${failure_log}"
  # The mock applies one status globally; use a successful first run and a
  # failing second run by selecting the target from the current directory.
  cat >"${MOCK_BIN}/task" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'command=task cwd=%q args=' "${PWD}"
  printf '%q ' "$@"
  printf '\n'
} >>"${MOCK_LOG}"
[[ $# -eq 1 ]] || exit 97
case "$1" in
  terraform:switch) exit 0 ;;
  terraform:validate)
    mkdir -p .terraform
    if [[ ${PWD} == */examples/two ]]; then
      printf '1' >.terraform/validate
      cp "${MOCK_MODULE_FAILURE_LOG}" .terraform/validate.log
      exit 1
    fi
    printf '0' >.terraform/validate
    cp "${MOCK_MODULE_SUCCESS_LOG}" .terraform/validate.log
    exit 0
    ;;
  *) exit 97 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/task"
  export MOCK_MODULE_SUCCESS_LOG="${success_log}" MOCK_MODULE_FAILURE_LOG="${failure_log}"

  run validate:module

  assert_failure
  assert_call_count task 4
  assert_summary_contains 'Example one is valid'
  assert_summary_contains 'Invalid configuration'
}
