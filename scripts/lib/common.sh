#!/usr/bin/env bash
# vim:set ft=bash:

set -euo pipefail

# Pre-bind these variables from the environment before use to ensure we both set them with default values, and that do
# not fail when using unbound variables
CI=${CI:-false}
DEBUG=${DEBUG:-}
LIB_DIR=${LIB_DIR:-../lib}

# We need a general variable which can be used to refer to the branch we're running against, and as GITHUB_HEAD_REF is
# only set for pull_request events, we will default it to main for other events. Essentially, if we're not running in a
# pull request, we'll assume we're running against the main branch.
export GITHUB_HEAD_REF=${GITHUB_HEAD_REF:-main}

# shellcheck source=check.sh
source "${LIB_DIR}/check.sh"
# shellcheck source=github.sh
source "${LIB_DIR}/github.sh"
# shellcheck source=terraform.sh
source "${LIB_DIR}/terraform.sh"
# shellcheck source=output.sh
source "${LIB_DIR}/output.sh"

# shellcheck source=../lib/init.sh
source "${LIB_DIR}/init.sh"
# shellcheck source=../lib/validate.sh
source "${LIB_DIR}/validate.sh"
# shellcheck source=../lib/plan.sh
source "${LIB_DIR}/plan.sh"
# shellcheck source=../lib/apply.sh
source "${LIB_DIR}/apply.sh"
