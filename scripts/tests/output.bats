#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load 'helpers/load'
load_helpers

@test "output debug is silent locally unless DEBUG is set" {
  load_common
  export CI=false DEBUG=

  run output:debug 'hidden message'
  assert_success
  assert_output ''

  export DEBUG=true
  run output:debug 'visible message'
  assert_success
  assert_output --partial 'DEBUG: visible message'
}

@test "output debug uses GitHub debug syntax in CI" {
  load_common
  export CI=true DEBUG=

  run output:debug 'debug message'

  assert_success
  assert_output '::debug::debug message'
}

@test "output annotations use local and GitHub formats" {
  load_common
  export CI=false

  run output:notice 'Notice title' 'notice details'
  assert_output --partial 'NOTICE'
  assert_output --partial 'Notice title'
  run output:warning 'Warning title' 'warning details'
  assert_output --partial 'WARNING'
  run output:error 'Error title' 'error details'
  assert_output --partial 'ERROR'

  export CI=true
  run output:notice 'Notice title' 'notice details'
  assert_output '::notice title=Notice title::notice details'
  run output:warning 'Warning title' 'warning details'
  assert_output '::warning title=Warning title::warning details'
  run output:error 'Error title' 'error details'
  assert_output '::error title=Error title::error details'
}

@test "output variable reports empty and populated values" {
  load_common
  export CI=false DEBUG=true
  unset EMPTY_VALUE
  export FULL_VALUE=present

  run output:variables EMPTY_VALUE FULL_VALUE

  assert_success
  assert_output --partial 'EMPTY_VALUE empty'
  assert_output --partial 'FULL_VALUE = present'
}

@test "output stage and step use the expected local formatting" {
  load_common

  run output:stage 'Validation'
  assert_success
  assert_output --partial 'Validation'
  assert_output --partial '==>'

  run output:step 'Terraform validate'
  assert_success
  assert_output --partial 'Terraform validate'
  assert_output --partial '->'
}

@test "output template renders a repository template with real gomplate" {
  load_common
  write_lockfile
  write_log "${CONFIGURATION}/.terraform/validate.log" 'Terraform validation passed'
  context="${TEST_ROOT}/context.json"
  cat >"${context}" <<'EOF'
{"Summary":{"Terraform":"1.9.0","Providers":{"hashicorp/aws":"5.0.0"},"ExitStatus":0},"Warnings":[],"Errors":[]}
EOF

  run output:template "${context}" terraform-validate-pass.md.t

  assert_success
  assert_output --partial 'terraform validate'
  assert_output --partial 'Terraform validation passed'
  assert_output --partial 'terraform: 1.9.0'
}

@test "output template rejects a missing template" {
  load_common
  context="${TEST_ROOT}/context.json"
  printf '{}' >"${context}"

  run output:template "${context}" does-not-exist.md.t

  assert_failure
  assert_output --partial 'Template Not Found'
}

@test "output template propagates a gomplate failure" {
  load_common
  context="${TEST_ROOT}/context.json"
  printf '{"Summary":{}}' >"${context}"
  template="${TEST_ROOT}/bad-template.md.t"
  printf '{{ invalid gomplate syntax' >"${template}"
  export TMPL_DIR="${TEST_ROOT}"

  run output:template "${context}" "$(basename "${template}")"

  assert_failure
}
