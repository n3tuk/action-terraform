#!/usr/bin/env bats

load 'helpers/load'
load_helpers

@test "common sources every library and exposes the public functions" {
  load_common

  for function in \
    'check:variables' 'check:variable' 'check:commands' 'check:command' \
    'check:path' 'check:name' 'exit:error' \
    'github:group:start' 'github:group:end' 'github:path' 'github:output' \
    'version' 'providers' \
    'output:variables' 'output:variable' 'output:debug' 'output:stage' 'output:step' \
    'output:notice' 'output:warning' 'output:error' 'output:template' \
    'init:response' 'init:context' 'init:warnings' 'init:errors' \
    'validate' 'validate:module' 'validate:discover' 'validate:configuration' 'validate:response' \
    'validate:context' 'validate:warnings' 'validate:errors' \
    'plan' 'plan:response' 'plan:context' 'plan:trim' 'plan:warnings' 'plan:errors' \
    'plan:changes' 'plan:resources' 'plan:sources' \
    'apply' 'apply:response' 'apply:context' 'apply:warnings' 'apply:errors' 'apply:changes'; do
    declare -F "${function}"
  done
}

@test "common defaults GITHUB_HEAD_REF when it is absent" {
  run bash -c 'unset GITHUB_HEAD_REF; export LIB_DIR="$LIB_ROOT"; source "$LIB_DIR/common.sh"; printf "%s" "$GITHUB_HEAD_REF"'

  assert_success
  assert_output 'main'
}

@test "common preserves an explicit GITHUB_HEAD_REF" {
  run bash -c 'export LIB_DIR="$LIB_ROOT" GITHUB_HEAD_REF=release/test; source "$LIB_DIR/common.sh"; printf "%s" "$GITHUB_HEAD_REF"'

  assert_success
  assert_output 'release/test'
}

@test "common can be sourced from outside the repository" {
  run bash -c 'cd "$TEST_ROOT"; export LIB_DIR="$LIB_ROOT" TMPL_DIR="$TEMPLATE_ROOT"; source "$LIB_DIR/common.sh"; printf "%s" "$GITHUB_HEAD_REF"'

  assert_success
  assert_output 'feature/test'
}
