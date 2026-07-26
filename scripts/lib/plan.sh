#!/usr/bin/env bash
# vim:set ft=bash:

# Run the terraform:plan task for the requested configuration and then process the output in to notices and through
# templates which can be used to provide information about the plan in the GitHub Workflow that called this action.
function plan {
  local dir=${PWD} status context
  context="$(mktemp -t gomplate-context.XXX.json)"

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
    .terraform/validate .terraform/validate.log \
    .terraform/plan .terraform/plan.log .terraform/plan.trimmed.log

  set +e # We must allow the terraform:switch and terraform:validate tasks to fail, so we can process the results
  task terraform:switch
  task terraform:plan
  status=${?}
  set -e

  output:variables context
  init:response "${context}"
  validate:response "${context}"
  plan:response "${context}"

  cd "${dir}" || return 1
  return ${status}
}

# Build a response to the terraform:plan task, if run, indicating whether the plan was successful or not, and providing
# a summary of the changes that will be made if the execution plan was successfully built, and any warnings or errors
# that were issued, if not.
function plan:response {
  local context="${1}" status
  status=$(cat .terraform/plan 2>/dev/null || echo -n "255")

  # If the command has not been run skip processing the response, as it may not have been a dependent task at this time.
  if [[ ${status:-255} -eq 255 ]]; then
    return 0
  fi

  plan:trim
  plan:context "${context}" "${status}"

  if [[ ${status} -eq 0 ]]; then
    output:notice "terraform plan ${TF_NAME}" "Terraform has built the execution plan for ${TF_NAME}."
    output:template "${context}" terraform-plan-pass.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
    return 0
  fi

  output:error "terraform plan ${TF_NAME}" "Terraform failed to build the execution plan for ${TF_NAME}."
  output:template "${context}" terraform-plan-fail.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Generate a context file which can be passed to gomplate templates to provide information about the terraform plan
# action, such as the Terraform version, the providers used, the number of resources and data sources, the changes that
# will be made, and any warnings or errors that were issued
function plan:context {
  local context="${1}" status="${2}"

  cat <<-EOF >"${context}"
    {
      "Summary": {
        "Terraform": "$(version)",
        "Providers": $(providers),
        "Resources": $(plan:resources),
        "DataSources": $(plan:sources),
        "ExitStatus": ${status}
      },
      "Changes": $(plan:changes),
      "Warnings": $(plan:warnings),
      "Errors": $(plan:errors)
    }
	EOF
}

# Trim the file containing the Terraform plan and clean up the output by stripping the refreshing of data sources and
# resource metadata requests from the start, and remove the Terraform apply instruction message from the end
function plan:trim {
  if [[ ! -r .terraform/plan.log ]]; then
    output:warning "Plan Log Not Found" \
      "The Terraform plan log file could not be found, so cannot be processed."
    return 0
  fi

  awk '
    BEGIN              { show=0 }
    /^Terraform/       { show=1 }
    /^Planning failed/ { show=1 }
    /^\s+Error:/       { show=1 }
    /^─+/              { show=0 }
                       { if (show==1) { print } }
  ' .terraform/plan.log \
    >.terraform/plan.trimmed.log
}

# Get all the warnings issued by Terraform during the building of the execution plan for this configuration
function plan:warnings {
  local check='^\s*Warning: '

  if [[ ! -r .terraform/plan.log ]]; then
    echo -n '[]'
    return 0
  fi

  grep -P "${check}" .terraform/plan.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}

# Get all the errors issued by Terraform during the building of the execution plan for this configuration
function plan:errors {
  local check='^\s*Error: '

  if [[ ! -r .terraform/plan.log ]]; then
    echo '["Terraform exited before starting the plan process, or no plan.log could be found"]'
    return 0
  fi

  grep -P "${check}" .terraform/plan.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}

# Read the plan output and check if the plan message exists, and if so, output what those changes are, stripping the
# plan prefix first, otherwise fall back to the default message for all other cases
function plan:changes {
  local check='^Plan:( \d+ to import,)? \d+ to add, \d+ to change, \d+ to destroy'
  local default='{"Add": 0, "Change": 0, "Destroy": 0}'

  [[ ! -r .terraform/plan.log ]] && echo "${default}" && return 0

  if ! grep -qP "${check}" .terraform/plan.log; then
    echo -n "${default}"
    return 0
  fi

  grep -oP "${check}" .terraform/plan.log \
    | cut -d ' ' -f 2- \
    | sed -e 's/, /\n/g' \
    | awk '
        BEGIN { printf "{" }
         /to import/ { printf "\"Import\": %d, ", $1}
         /to add/ { printf "\"Add\": %d, ", $1}
         /to change/ { printf "\"Change\": %d, ", $1 }
         /to destroy/ { printf "\"Destroy\": %d", $1 }
        END { printf "}" }'
}

# Get the number of resources which currently exist within the state file
function plan:resources {
  [[ ! -r .terraform/plan.log ]] && echo 0 && return 0

  grep -Pc '^[a-z]\S+: Refreshing state...' .terraform/plan.log \
    2>/dev/null \
    || echo -n 0 # Force reporting a zero count when grep finds no matches
}

# Get the number of data sources which currently exist within the state file
function plan:sources {
  [[ ! -r .terraform/plan.log ]] && echo 0 && return 0

  grep -Pc '^[a-z]\S+: Reading...' .terraform/plan.log \
    2>/dev/null \
    || echo -n 0
}
