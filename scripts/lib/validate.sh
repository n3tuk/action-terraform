#!/usr/bin/env bash
# vim:set ft=bash:

# TODO: This has not been tested with Terraform modules and will likely need some additional work to fully support that
#       use-case. Either this will need to be updated to use `terraform:validate:*` tasks to call each module
#       individually and then process the results in a loop with init:response and validate:response being updated to
#       handle the directory change or the module can add dedicated `Taskfile.yaml` files in to each example/
#       configuration and then run the same `task terraform:validate` task locally in each example/ configuration, and
#       process the results in that loop.

# Decide which validation function to run based on whether we're validating a Terraform module or a Terraform
# configuration, providing a single entry point for the validation of Terraform configurations and modules.
function validate {
  if [[ ${TF_MODULE} == "true" ]]; then
    validate:module
    return ${?}
  else
    validate:configuration
    return ${?}
  fi
}

# Using validate:discover, run validate:configuration for each of the configurations found under the module's examples/
# directory, and return a non-zero exit code if any one (or more) of the example configurations fail validation.
function validate:module {
  local name configuration context count=0 status=0
  context="$(mktemp -t gomplate-context.XXX.json)"

  while IFS= read -r configuration; do

    [[ -n ${configuration} && -d ${configuration} ]] || continue

    count=$((count + 1))
    name="${configuration}"

    # Deal with the different methods of referencing the location of the Terraform configuration, including relative to
    # the repository (path/to), relative to the root of the repository (./path/to), and absolute paths (/path/to). For
    # each case, provide a clean version of the path which can be used for display purposes.
    if [[ ${configuration:0:1} != "/" ]]; then
      configuration="${GITHUB_WORKSPACE}/${configuration}"
    fi

    # When running validate:configuration, override the TF_NAME and TF_PATH variable to point to the example/
    # configuration instead of the module root, simulating the validate script being called for each example/
    # configuration in turn.
    if ! TF_NAME="${name}" TF_PATH="${configuration}" \
      validate:configuration; then
      status=1
    fi
  done < <(validate:discover)

  if [[ ${count} -eq 0 ]]; then
    echo "{}" >"${context}"
    output:error "terraform validate ${TF_NAME}" \
      "No Terraform example configurations were found under ${TF_NAME}/examples."
    output:template "${context}" terraform-validate-missing.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
    return 1
  fi

  return "${status}"
}

# Discover all the example configurations under the module's examples/ directory, and return a list of those directories
# containing Terraform configuration files so we can validate them individually. If no examples/ directory exists,
# return an empty list
function validate:discover {
  [[ -d "${TF_PATH}/examples" ]] || return 0

  find "${TF_PATH}/examples" -type f -name '*.tf' -exec dirname '{}' ';' \
    | sort -u \
    | sed -e "s|^${GITHUB_WORKSPACE}/||"
}

# Run Terraform to (initialise and) validate the Terraform configuration found at the TF_PATH environment variable
function validate:configuration {
  local dir=${PWD} status context
  context="$(mktemp -t gomplate-context.XXX.json)"

  # We don't care about being able to access the state file during any validation (remote or otherwise), therefore
  # export the TF_BACKEND setting which will tell Taskfile to skip initialising the backend with the configuration.
  # This can only be supported when validating a configuration. All other actions will effectively ignore this setting.
  export TF_BACKEND=false

  output:variable PWD

  # Terraform no longer accepts the -chdir flag, so we must change into the configuration directory to run the init
  # command, and then change back to the original directory after it completes to run all other commands
  cd "${TF_PATH}" || return 1
  output:variable PWD

  if [[ ! -f .terraform.lock.hcl ]]; then
    output:warning "terraform init ${TF_NAME}" \
      "The Terraform configuration at ${TF_NAME} does not contain a .terraform.lock.hcl file, which means that the" \
      "versions of the providers used by this configuration are not pinned!"
  fi

  rm -f \
    .terraform/init .terraform/init.log \
    .terraform/validate .terraform/validate.log

  set +e # We must allow the terraform:switch and terraform:validate tasks to fail, so we can process the results
  task terraform:switch
  task terraform:validate
  status=${?}
  set -e

  output:variables context
  init:response "${context}"
  validate:response "${context}"

  cd "${dir}" || return 1
  return ${status}
}

# Build a response to the terraform:validate task, if run, indicating whether the validation was successful or not, and
# providing a summary of the warnings or errors that were issued, if not.
function validate:response {
  local context="${1}" status
  status=$(cat .terraform/validate 2>/dev/null || echo -n "255")

  # If the command has not been run skip processing the response, as it may not have been a dependent task at this time.
  if [[ ${status:-255} -eq 255 ]]; then
    return 0
  fi

  validate:context "${context}" "${status}"

  if [[ ${status} -eq 0 ]]; then
    output:notice "terraform validate ${TF_NAME}" "Terraform has validated the configuration at ${TF_NAME}."
    output:template "${context}" terraform-validate-pass.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
    return 0
  fi

  output:error "terraform validate ${TF_NAME}" "Terraform failed to validate the configuration at ${TF_NAME}."
  output:template "${context}" terraform-validate-fail.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Generate a context file which can be passed to gomplate templates to provide information about the terraform validate
# action, such as the Terraform version, the providers used, and any warnings or errors that were issued
function validate:context {
  local context="${1}" status="${2}"

  cat <<-EOF >"${context}"
    {
      "Summary": {
        "Terraform": "$(version)",
        "Providers": $(providers),
        "ExitStatus": ${status}
      },
      "Warnings": $(validate:warnings),
      "Errors": $(validate:errors)
    }
	EOF
}

# Get all the warnings issued by Terraform during the validation of the configuration
function validate:warnings {
  local check='^\s*Warning: '

  if [[ ! -r .terraform/validate.log ]]; then
    echo -n '[]'
    return 0
  fi

  grep -P "${check}" .terraform/validate.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || echo -n '[]'
}

# Get all the errors issued by Terraform during the validation of the configuration
function validate:errors {
  local check='^\s*Error: '

  if [[ ! -r .terraform/validate.log ]]; then
    echo -n '["Terraform exited before starting the validate process, or no validate.log could be found"]'
    return 0
  fi

  grep -P "${check}" .terraform/validate.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || echo -n '[]'
}
