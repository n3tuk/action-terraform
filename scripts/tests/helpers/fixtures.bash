#!/usr/bin/env bash

configure_task() {
  local target=${1} status=${2:-0} log_file=${3:-}
  local key=${target//:/_}
  key=${key^^}
  export "MOCK_TASK_${key}_STATUS=${status}"
  if [[ -n ${log_file} ]]; then
    export "MOCK_TASK_${key}_LOG=${log_file}"
  else
    unset "MOCK_TASK_${key}_LOG"
  fi
}

write_lockfile() {
  local file=${1:-${CONFIGURATION}/.terraform.lock.hcl}
  cat >"${file}" <<'EOF'
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.0.0"
  constraints = ">= 5.0.0"
  hashes      = ["h1:example"]
}

provider "registry.terraform.io/hashicorp/random" {
  version     = "3.6.0"
  constraints = ">= 3.6.0"
  hashes      = ["h1:example"]
}
EOF
}

write_log() {
  local file=${1}
  shift
  printf '%s\n' "$@" >"${file}"
}

write_init_log() {
  write_log "${1}" \
    'Initializing the backend...' \
    'Warning: Deprecated argument' \
    'Warning: Deprecated argument' \
    '  Error: Provider configuration error' \
    'Error: Terraform encountered problems during initialisation' \
    'Error: Provider configuration error'
}

write_validate_log() {
  write_log "${1}" \
    'Warning: Deprecated argument' \
    'Warning: Deprecated argument' \
    'Error: Invalid configuration' \
    'Error: Invalid configuration'
}

write_plan_log() {
  write_log "${1}" \
    'data.aws_caller_identity.current: Reading...' \
    'aws_instance.example: Refreshing state... [id=i-123]' \
    'Terraform used the selected providers to generate the following execution plan.' \
    'Warning: Deprecated argument' \
    '  # aws_instance.example will be created' \
    '  + resource "aws_instance" "example" {' \
    'Plan: 1 to add, 2 to change, 3 to destroy.' \
    '─────────────────────────────────────────────────────────────────────────────' \
    'Note: You did not use the -out option to save this plan, so Terraform cannot guarantee that exactly these actions will be performed if terraform apply is subsequently run.'
}

write_apply_log() {
  write_log "${1}" \
    'aws_instance.example: Creating...' \
    'Warning: Deprecated argument' \
    'Error: A partial apply error' \
    'Apply complete! Resources: 1 added, 2 changed, 3 destroyed.'
}
