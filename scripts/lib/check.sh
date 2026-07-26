#!/usr/bin/env bash
# vim:set ft=bash:

# Check to see if the variable name provided both exists and has a value associated with it, otherwise output an error
# and exit the script
function check:variables {
  local variable
  for variable in "${@}"; do
    check:variable "${variable}"
  done
}

# Check to see if the variable name provided both exists and has a value associated with it, otherwise output an error
# and exit the script
function check:variable {
  local variable=${1%%:*}
  local sensitive=0

  # Allow us to check for the presence of the variable, but not output the contents, when we know the information will
  # be sensitive (in most cases GitHub Actions should protect against this, but we should avoid doing it regardless,
  # where possible)
  if [[ ${1##*:} == "sensitive" ]]; then
    sensitive=1
  fi

  set +u # Don't error out on unbound variables in this part of the function
  if [[ -z ${!variable} ]]; then
    exit:error \
      "\$${variable} Not Found" \
      "The environment variable '${variable}' is missing and is required."
  fi
  set -u # We know the variable is bound now, restore the check

  if [[ ${sensitive} -eq 0 ]]; then
    output:variable "${variable}"
  else
    output:debug "\$${variable} exists"
  fi
}

# Check to see if all the commands provided exist and are executable (and as such are available via the $PATH variable),
# otherwise output an error and exit the script
function check:commands {
  local command
  for command in "${@}"; do
    check:command "${command}"
  done
}

# Check to see if the command provided both exists and is executable (and as such is available via the $PATH variable),
# otherwise error and exit the script
function check:command {
  if [[ ! -x "$(command -v "${1}")" ]]; then
    exit:error \
      "${1} Not Found" \
      "Missing the ${1} application. Please install and try again."
  fi
}

# Deal with the different methods of reference the location of the Terraform configuration, including relative to the
# repository (path/to), relative to the root of the repository (./path/to), and absolute paths within the repository
# (/path/to). For each case, provide a clean version of the path which can be used for display purposes. There is no
# context in which the path should be output of the repository root, so we will always output the path relative to the
# repository root, even if the input was an absolute path.
function check:path {
  local path=${1:-.}

  if [[ ${path} == "." || ${path} == "/" || ${path} == "./" ]]; then
    echo "${GITHUB_WORKSPACE}"
  elif [[ ${path:0:2} == "./" ]]; then
    echo "${GITHUB_WORKSPACE}/${path:2}"
  elif [[ ${path:0:1} == "/" ]]; then
    echo "${GITHUB_WORKSPACE}/${path:1}"
  else
    echo "${GITHUB_WORKSPACE}/${path}"
  fi
}

# Deal with the different methods of reference the location of the Terraform configuration, including relative to the
# repository (path/to), relative to the root of the repository (./path/to), and absolute paths within the repository
# (/path/to). For each case, provide a clean version of the path which can be used for display/naming purposes.
function check:name {
  local name=${1:-.}

  if [[ ${name} == "." || ${name} == "/" || ${name} == "./" ]]; then
    echo "."
  elif [[ ${name:0:2} == "./" ]]; then
    echo "${name}"
  elif [[ ${name:0:1} == "/" ]]; then
    echo "./${name:1}"
  else
    echo "./${name}"
  fi
}

# Output an error message for GitHub Actions and then immediately exit the script
function exit:error {
  output:error "${@}"
  exit 1
}
