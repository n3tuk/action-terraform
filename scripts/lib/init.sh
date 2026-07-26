#!/usr/bin/env bash
# vim:set ft=bash:

# NOTE: There is no init function here as we will not be running terraform init directly. This is handled by Taskfile
#       instead as a dependency of all of the Terraform tasks.

# Build a response to the terraform:init task, if run, indicating whether the initialisation was successful or not, and
# providing a summary of the warnings or errors that were issued, if not.
function init:response {
  local context="${1}" status
  status=$(cat .terraform/init 2>/dev/null || echo -n "255")

  # If the initialisation was successful, or was not run at this time as it was not a dependent task at this time, then
  # don't response with anything for the step summary, or any notices.
  if [[ ${status:-255} -eq 255 || ${status} -eq 0 ]]; then
    return 0
  fi

  init:context "${context}" "${status}"
  output:error "terraform init ${TF_NAME}" "Terraform failed to initialise the configuration at ${TF_NAME}."
  output:template "${context}" terraform-init-fail.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Generate a context file which can be passed to a gomplate template to provide information about the terraform
# initialisation, such as the Terraform version, the providers used, and any warnings or errors that were issued.
function init:context {
  local context="${1}" status="${2}"

  cat <<-EOF >"${context}"
    {
      "Summary": {
        "Terraform": "$(version)",
        "Providers": $(providers),
        "Resources": 0,
        "DataSources": 0,
        "ExitStatus": ${status}
      },
      "Changes": {
        "Add": 0,
        "Change": 0,
        "Destroy": 0
      },
      "Warnings": $(init:warnings),
      "Errors": $(init:errors)
    }
	EOF
}

# Get all the warnings issued by Terraform during the initialisation of this configuration.
function init:warnings {
  local check='^\s*Warning: '

  # If the file doesn't exist, don't run grep over it, but issue an empty array, grep will just issue a warning anyway.
  if [[ ! -r .terraform/init.log ]]; then
    echo -n '[]'
    return 0
  fi

  grep -P "${check}" .terraform/init.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}

# Get all the errors issued by Terraform during the initialisation of this configuration.
function init:errors {
  local check='^\s*Error: '

  # If the file doesn't exist, don't run grep over it, but issue a standard error message instead.
  if [[ ! -r .terraform/init.log ]]; then
    echo -n '["Terraform exited before initialising the configuration, or no init.log could be found"]'
    return 0
  fi

  # NOTE: Terraform outputs a general error message about failing to initilise at the head of the output, which will
  #       normally be accepted and processed by grep, so ensure we filter out that message separately before passing all
  #       other error messages back.
  grep -P "${check}" .terraform/init.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | grep -v 'Terraform encountered problems during initialisation' \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}
