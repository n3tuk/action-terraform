#!/usr/bin/env bash
# vim:set ft=bash:

# Set up colours for improving output
DIM='\033[2m'
ERROR='\033[0;31m'
WARNING='\033[0;93m'
NOTICE='\033[0;37m'
STAGE='\033[0;33m'
STEP='\033[0;34m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Show the value of each of the variables provided
function output:variables {
  for variable in "${@}"; do
    output:variable "${variable}"
  done
}

# Show the value of the variable
function output:variable {
  local value="${!1-}"
  if [[ -z ${value} ]]; then
    output:debug "\$${1} empty"
  else
    output:debug "\$${1} = ${value}"
  fi
}

# Output a debug message for GitHub Actions
function output:debug {
  if [[ ${CI} == "true" ]]; then
    echo >&2 "::debug::${*}"
  elif [[ -n ${DEBUG} ]]; then
    echo >&2 -e "${DIM}DEBUG: ${*}${NC}"
  fi
}

# Output the header for a new stage in the application
function output:stage {
  echo -e "${STAGE}==>${NC} ${WHITE}${1}${NC}"
}

# Output the message for a step in the application
function output:step {
  echo -e " ${STEP}->${NC} ${WHITE}${1}${NC}"
}

# Output a notice message for GitHub Actions
function output:notice {
  local title=${1}
  shift

  if [[ ${CI} == "true" ]]; then
    echo "::notice title=${title}::${*}"
  else
    echo >&2 -e "${NOTICE}NOTICE${NC}: ${NOTICE}${title}${NC}${*:+ (${*})}"
  fi
}

# Output a warning message for GitHub Actions
function output:warning {
  local title=${1}
  shift

  if [[ ${CI} == "true" ]]; then
    echo "::warning title=${title}::${*}"
  else
    echo >&2 -e "${WARNING}WARNING${NC}: ${WARNING}${title}${NC}${*:+ (${*})}"
  fi
}

# Output an error message for GitHub Actions
function output:error {
  local title=${1}
  shift

  if [[ ${CI} == "true" ]]; then
    echo "::error title=${title}::${*}"
  else
    echo >&2 -e "${ERROR}ERROR${NC}: ${ERROR}${title}${NC}${*:+ (${*})}"
  fi
}

function output:template {
  local context=${1} template=${2}

  output:debug "Rendering template ${TMPL_DIR}/${template} with context from ${context}"
  output:debug "$(jq -c '.' "${context}" 2>&1 || true)"

  # shellcheck disable=SC2154 # TMPL_DIR is set in the parent script
  if [[ ! -r "${TMPL_DIR}/${template}" ]]; then
    output:error "Template Not Found" \
      "The template file '${TMPL_DIR}/${template}' does not exist."
    return 1
  fi

  (
    # Change in to the templates directory to ensure that gomplate can resolve any relative paths in the template, and
    # not where the parent script is being run from
    cd "${TMPL_DIR}" || exit 1
    GOMPLATE_LOG_FORMAT=simple \
      gomplate \
      --missing-key default \
      --context "terraform=file://${context}" \
      --file "${TMPL_DIR}/${template}"
  )

  # Ensure there is at least one blank line after the rendered template to prevent it being concatenated with any
  # subsequent output, which may be rendered as markdown and cause formatting issues
  echo
  echo
}
