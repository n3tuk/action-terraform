#!/usr/bin/env bash

assert_call() {
  local command=${1}
  shift
  local expected_args rendered line
  printf -v rendered '%q ' "$@"
  rendered=${rendered% }
  expected_args="args=${rendered}"
  while IFS= read -r line; do
    if [[ ${line} == "command=${command} "* && ${line} == *"${expected_args}"* ]]; then
      return 0
    fi
  done <"${MOCK_LOG}"
  printf 'Expected call not found: command=%s %s\nLog:\n' "${command}" "${expected_args}" >&2
  cat "${MOCK_LOG}" >&2
  return 1
}

assert_call_count() {
  local command=${1} expected=${2} actual
  actual=$(grep -c "^command=${command} " "${MOCK_LOG}" || true)
  assert_equal "${actual}" "${expected}"
}

assert_no_call() {
  local command=${1}
  if grep -q "^command=${command} " "${MOCK_LOG}"; then
    printf 'Unexpected call found for %s:\n' "${command}" >&2
    cat "${MOCK_LOG}" >&2
    return 1
  fi
}

assert_file_contains() {
  local file=${1} expected=${2}
  grep -F -- "${expected}" "${file}"
}

assert_file_not_contains() {
  local file=${1} unexpected=${2}
  if grep -F -- "${unexpected}" "${file}"; then
    printf 'Unexpected content found in %s: %s\n' "${file}" "${unexpected}" >&2
    return 1
  fi
}

assert_json_value() {
  local file=${1} filter=${2} expected=${3} actual
  actual=$(jq -c "${filter}" "${file}")
  assert_equal "${actual}" "${expected}"
}

assert_summary_contains() {
  local expected=${1}
  assert_file_contains "${GITHUB_STEP_SUMMARY}" "${expected}"
}

assert_summary_not_written() {
  [[ ! -s ${GITHUB_STEP_SUMMARY} ]]
}
