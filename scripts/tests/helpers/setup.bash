#!/usr/bin/env bash

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
LIB_ROOT="${REPO_ROOT}/scripts/lib"
TEMPLATE_ROOT="${REPO_ROOT}/scripts/templates"

setup() {
  TEST_ROOT="${BATS_TEST_TMPDIR}/sandbox"
  MOCK_BIN="${TEST_ROOT}/bin"
  WORKSPACE="${TEST_ROOT}/workspace"
  CONFIGURATION="${WORKSPACE}/terraform"
  MOCK_LOG="${TEST_ROOT}/mock.log"
  GITHUB_STEP_SUMMARY="${TEST_ROOT}/step-summary.md"
  GITHUB_PATH="${TEST_ROOT}/github.path"
  GITHUB_OUTPUT="${TEST_ROOT}/github.output"

  mkdir -p "${MOCK_BIN}" "${CONFIGURATION}/.terraform"
  : >"${MOCK_LOG}"
  : >"${GITHUB_STEP_SUMMARY}"
  : >"${GITHUB_PATH}"
  : >"${GITHUB_OUTPUT}"

  export REPO_ROOT LIB_ROOT TEMPLATE_ROOT TEST_ROOT MOCK_BIN WORKSPACE CONFIGURATION MOCK_LOG
  export GITHUB_STEP_SUMMARY GITHUB_PATH GITHUB_OUTPUT
  export PATH="${MOCK_BIN}:${PATH}"
  export GITHUB_WORKSPACE="${WORKSPACE}"
  export GITHUB_REPOSITORY="example/test-repository"
  export GITHUB_HEAD_REF="feature/test"
  export CI=false DEBUG=
  export TF_ACTION=validate TF_CONFIGURATION=terraform TF_MODULE=false
  export TF_NAME=./terraform TF_PATH="${CONFIGURATION}"
  export MOCK_TERRAFORM_VERSION='Terraform v1.9.0'
  export MOCK_TERRAFORM_STATUS=0
  export MOCK_TFSWITCH_STATUS=0

  install_mocks
}

load_common() {
  export LIB_DIR="${LIB_ROOT}" TMPL_DIR="${TEMPLATE_ROOT}"
  # shellcheck source=/dev/null
  source "${LIB_ROOT}/common.sh"
  # common.sh intentionally enables errexit for production; tests need to inspect
  # expected failures without terminating the BATS test process.
  set +e
}

install_mocks() {
  cat >"${MOCK_BIN}/task" <<'MOCK_TASK'
#!/usr/bin/env bash
set -euo pipefail

log_call() {
  local command=${1}; shift
  {
    printf 'command=%s cwd=%q args=' "${command}" "${PWD}"
    printf '%q ' "$@"
    printf 'env.TF_IN_AUTOMATION=%q env.NO_COLOR=%q env.TASK_OUTPUT=%q env.TF_BACKEND=%q\n' \
      "${TF_IN_AUTOMATION-}" "${NO_COLOR-}" "${TASK_OUTPUT-}" "${TF_BACKEND-}"
  } >>"${MOCK_LOG}"
}

log_call task "$@"
[[ $# -eq 1 ]] || { printf 'unexpected task arguments\n' >&2; exit 97; }
target=$1
key=${target//:/_}
key=${key^^}
case "${target}" in
  terraform:switch) artifact=;;
  terraform:validate) artifact=validate;;
  terraform:plan) artifact=plan;;
  terraform:apply) artifact=apply;;
  *) printf 'unexpected task target: %s\n' "${target}" >&2; exit 97;;
esac

status_var="MOCK_TASK_${key}_STATUS"
log_var="MOCK_TASK_${key}_LOG"
status=${!status_var:-0}
mkdir -p .terraform
if [[ -n ${artifact} ]]; then
  printf '%s' "${status}" >".terraform/${artifact}"
  log_file=${!log_var:-}
  if [[ -n ${log_file} && -f ${log_file} ]]; then
    cp "${log_file}" ".terraform/${artifact}.log"
  else
    : >".terraform/${artifact}.log"
  fi
  if [[ ${artifact} == plan && ${status} -eq 0 ]]; then
    : >terraform.tfplan
  fi
fi
exit "${status}"
MOCK_TASK

  cat >"${MOCK_BIN}/tfswitch" <<'MOCK_TFSWITCH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'command=tfswitch cwd=%q args=' "${PWD}"
  printf '%q ' "$@"
  printf '\n'
} >>"${MOCK_LOG}"
exit "${MOCK_TFSWITCH_STATUS:-0}"
MOCK_TFSWITCH

  cat >"${MOCK_BIN}/terraform" <<'MOCK_TERRAFORM'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'command=terraform cwd=%q args=' "${PWD}"
  printf '%q ' "$@"
  printf '\n'
} >>"${MOCK_LOG}"
[[ $# -ge 1 ]] || { printf 'terraform subcommand required\n' >&2; exit 98; }
case "$1" in
  version)
    printf '%s\n' "${MOCK_TERRAFORM_VERSION:-Terraform v1.9.0}"
    ;;
  *)
    if [[ ${MOCK_TERRAFORM_ALLOW_OTHER:-false} != true ]]; then
      printf 'unexpected terraform subcommand: %s\n' "$1" >&2
      exit 98
    fi
    printf '%s\n' "${MOCK_TERRAFORM_OUTPUT:-}"
    exit "${MOCK_TERRAFORM_STATUS:-0}"
    ;;
esac
MOCK_TERRAFORM

  chmod +x "${MOCK_BIN}/task" "${MOCK_BIN}/tfswitch" "${MOCK_BIN}/terraform"
}
