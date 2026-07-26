#!/usr/bin/env bash
# vim:set ft=bash:

# Run the terraform:apply task for the requested configuration (using the generated execution plan, if provided) and
# then process the output in to notices and through templates which can be used to provide information about the plan in
# the GitHub Workflow that called this action.
function apply {
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
    .terraform/plan .terraform/plan.log .terraform/plan.trimmed.log \
    .terraform/apply .terraform/apply.log

  set +e # We must allow the terraform:switch and terraform:validate tasks to fail, so we can process the results
  task terraform:switch
  task terraform:apply
  status=${?}
  set -e

  output:variable context
  init:response "${context}"
  validate:response "${context}"
  plan:response "${context}"
  apply:response "${context}"

  cd "${dir}" || return 1
  return ${status}
}

# Build a response to the terraform:apply task, if run, indicating whether the apply was successful or not, and
# providing a summary of the changes that were made (even if only partially applied), and any warnings or errors that
# were issued, if not.
function apply:response {
  local context="${1}" status
  status=$(cat .terraform/apply 2>/dev/null || echo -n "255")

  # If the command has not been run skip processing the response, as it may not have been a dependent task at this time.
  if [[ ${status:-255} -eq 255 ]]; then
    return 0
  fi

  apply:context "${context}" "${status}"

  if [[ ${status} -eq 0 ]]; then
    output:notice "terraform apply ${TF_NAME}/terraform.tfplan" \
      "Terraform has applied the execution plan for ${TF_NAME}."
    output:template "${context}" terraform-apply-pass.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
    return 0
  fi

  output:error "terraform apply ${TF_NAME}/terraform.tfplan" \
    "Terraform failed to apply the execution plan for ${TF_NAME}."
  output:template "${context}" terraform-apply-fail.md.t >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Generate a context file which can be passed to gomplate templates to provide information about the terraform apply
# action, such as the Terraform version, the providers used, and the changes that were be made, as well as any warnings
# or errors that were issued.
function apply:context {
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
      "Changes": $(apply:changes),
      "Warnings": $(apply:warnings),
      "Errors": $(apply:errors)
    }
	EOF
}

# Get all the warnings issued by Terraform during the application of the execution plan
function apply:warnings {
  local check='^\s*Warning: '

  if [[ ! -r .terraform/apply.log ]]; then
    echo -n '[]'
    return 0
  fi

  grep -P "${check}" .terraform/apply.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}

# Get all the errors issued by Terraform during the building of the execution plan for this configuration
function apply:errors {
  local check='^\s*Error: '

  if [[ ! -r .terraform/apply.log ]]; then
    echo '["Terraform exited before starting the apply process, or no apply.log could be found"]'
    return 0
  fi

  grep -P "${check}" .terraform/apply.log \
    | sed -e "s/${check}//" \
    | sort \
    | uniq \
    | jq -R -s -c 'split("\n")[:-1]' \
    || true
}

# Read the apply output and check if the "apply complete" message exists, and if so, output what those changes are,
# stripping the prefix first, otherwise fall back to the default message for all other cases
function apply:changes {
  local check default
  check='^Apply complete! Resources: \d+ added, \d+ changed, \d+ destroyed'
  default='{"Added": 0, "Changed": 0, "Destroyed": 0}'

  [[ ! -r .terraform/apply.log ]] && echo "${default}" && return 0

  if ! grep -qP "${check}" .terraform/apply.log; then
    echo -n "${default}"
    return 0
  fi

  grep -oP "${check}" .terraform/apply.log \
    | cut -d ' ' -f 4- \
    | sed -e 's/, /\n/g' \
    | awk '
        BEGIN { printf "{" }
         /added/ { printf "\"Added\": %d,", $1}
         /changed/ { printf "\"Changed\": %d,", $1 }
         /destroyed/ { printf "\"Destroyed\": %d", $1 }
        END { printf "}" }'
}
