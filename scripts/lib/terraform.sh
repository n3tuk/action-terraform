#!/usr/bin/env bash
# vim:set ft=bash:

# Get the versions of Terraform and all the providers required by this configuration as a list
function version {
  # The .terraform.lock.hcl file does not contain information about the required version of Terraform, so pull that in
  # from the environment directly by running terraform and processing the output
  terraform version \
    | grep -oP '^Terraform v[0-9][0-9\.]+(?:-.+)?' \
    | cut -d v -f 2
}

function providers {
  local providers

  # Iterate over each of the provider blocks in the .terraform.hcl.lock file and from that, extract the version
  providers=$(
    echo -n "{"
    hcledit \
      -f .terraform.lock.hcl \
      block list \
      | cut -d / -f 2- \
      | sort \
      | while read -r provider; do
        echo -n "\"${provider}\": \""
        hcledit \
          -f .terraform.lock.hcl \
          attribute get "provider.registry\\.terraform\\.io/${provider}.version" \
          | tr -d \" | tr -d '\n'
        echo -n '",'
      done
    echo -n "}"
  )

  echo "${providers/,\}/\}}"
}
