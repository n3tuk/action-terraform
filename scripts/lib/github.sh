#!/usr/bin/env bash
# vim:set ft=bash:
# shellcheck disable=SC2016 # Backticks don't need to expand in this file

# Initiate the starting of a grouped output for this GitHub Actions step, which
# will be collapsed by default in the GitHub Actions UI, but can be expanded by
# clicking on it.
function github:group:start {
  if [[ ${CI} == "true" ]]; then
    echo "::group::${1}"
  fi

  output:stage "${1}"
}

# End the grouped output section for GitHub Actions for this step.
function github:group:end {
  if [[ ${CI} == "true" ]]; then
    echo "::endgroup::"
  fi
}

# Append a directory to PATH for GitHub Workflows
function github:path {
  output:debug "add:path \"${1}\" >> ${GITHUB_PATH:-/dev/null}"
  echo "${1}" >>"${GITHUB_PATH:-/dev/null}"
}

# Add an output in the GitHub Action for GitHub Workflows
function github:output {
  output:debug "add:output ${1}=\"${2}\" >> ${GITHUB_OUTPUT:-/dev/null}"
  echo "${1}=${2}" >>"${GITHUB_OUTPUT:-/dev/null}"
}
