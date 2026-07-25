# Terraform GitHub Action for n3tuk

[![release-drafter](https://github.com/n3tuk/action-terraform/actions/workflows/draft-release.yaml/badge.svg?branch=main)](https://github.com/n3tuk/action-terraform/actions/workflows/draft-release.yaml)
[![build-release](https://github.com/n3tuk/action-terraform/actions/workflows/build-release.yaml/badge.svg)](https://github.com/n3tuk/action-terraform/actions/workflows/build-release.yaml)

A GitHub Action to help manage the lifecycle of [Terraform][terraform] configurations, including the initialisation,
validation, planning, and application of the changes to infrastructure across multiple providers.

[terraform]: https://www.terraform.io/

## Taskfiles

The process of running Terraform is automated and simplified through the use of [Taskfile][taskfile] files, which are
executed by this GitHub Action instead of calling Terraform directly. This helps meet one of the core principals of
CI/CD, which is to ensure that the process of running tasks is consistent across all environments, including local
development, and automated CI/CD pipelines.

[taskfile]: https://taskfile.dev/

> [!NOTE]
>
> This action assumes that the GitHub Workflow it is run within has already been fully pre-configured; that all
> environment variables and required credentails are avialbale before running each `task`. OIDC authentication to
> third-party services, such AWS, GCP, Authentik, and Vault, must be set up in the GitHub Workflow before running this
> action.

## Reporting

Due to the limitations of GitHub comments on pull requests (mainly the 65,000 character limit), this action will report
the results of Terraform using GitHub Step Summaries and annotations. For larger plans this will allow clearer reporting
and minimise the risk of truncation of the plans.

The plan and changes can always be viewed in the GitHub Actions logs, and the plan can be downloaded as an artifact for
review if necessary, within 90 days of it being created.

### Concurrency

When working with Terraform, it is important to ensure that only one of any `refresh`, `plan` (including drift checks),
or the `apply` actions is run at a time. This is critical to avoid conflicts between workflow runs and ensure that the
state of the infrastructure is consistent.

You can use the GitHub Workflow [concurrency][concurrency] feature to achieve this. By setting a concurrency group for
your Terraform jobs, you can ensure that if one job is running, any new jobs will be paused until the current job
finishes.

[concurrency]:
  https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency

```yaml
jobs:
  plan:
    name: Plan Terraform

    concurrency:
      # Ensure that GitHub runs a single concurrent Terraform job across all GitHub Workflows in this repository so
      # that, for example, any plan action for a new pull request will be paused and held behind another plan or apply
      # action from the main branch.
      group: ${{github.repository}}:terraform
      cancel-in-progress: false

    steps: []
```

<!-- action-docs-inputs source="action.yaml" -->

### Inputs

| Name            | Description                                                                                                                                                                                                                        | required | default     |
| :-------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------- |
| `action`        | The action to perform through this Action, which can be one of the following: <code>validate</code>, <code>plan</code>, <code>apply</code>, <code>refresh</code>, <code>drift</code>, or <code>plan-and-apply</code>.              | `true`   | `plan`      |
| `configuration` | The path to the Terraform configuration to target for the specified action.                                                                                                                                                        | `true`   | `terraform` |
| `module`        | Set to <code>true</code> when the target configuration is a Terraform module. Module validation skips the module root and instead initialises and validates Terraform example configurations found beneath <code>examples/</code>. | `false`  | `"false"`   |

<!-- action-docs-inputs source="action.yaml" -->

<!-- action-docs-outputs source="action.yaml" -->

<!-- action-docs-outputs source="action.yaml" -->

## Testing

The BATS test suite validates the `scripts/bin/validate`, `scripts/bin/plan`, and `scripts/bin/apply` scripts, including
all library functions and [gomplate][gomplate] template rendering.

[gomplate]: https://github.com/hairyhenderson/gomplate

### Dependencies

The following tools must be installed and available on your `$PATH` before running the tests:

| Tool                                                      | Version  | Purpose                     |
| :-------------------------------------------------------- | :------- | :-------------------------- |
| [bats-core](https://github.com/bats-core/bats-core)       | ≥ 1.10.0 | Test runner                 |
| [bats-support](https://github.com/bats-core/bats-support) | ≥ 0.3.0  | BATS helper library         |
| [bats-assert](https://github.com/bats-core/bats-assert)   | ≥ 2.1.0  | BATS assertion library      |
| [bats-file](https://github.com/bats-core/bats-file)       | ≥ 0.4.0  | BATS file assertion library |
| [gomplate](https://github.com/hairyhenderson/gomplate)    | 5.0.0    | Template rendering          |
| [hcledit](https://github.com/minamijoyo/hcledit)          | ≥ 0.2.9  | HCL file editing            |
| [jq](https://jqlang.org)                                  | ≥ 1.6    | JSON processing             |

The BATS helper libraries (`bats-support`, `bats-assert`, `bats-file`) must be installed to `/usr/lib/bats/` (the
default path used by `bats_load_library`). This path can be overridden by setting the `BATS_LIB_PATH` environment
variable to the directory containing the libraries before running the tests.

On macOS, install bats-core and its libraries via Homebrew:

```shell
$ brew install bats-core
$ brew install bats-core/bats-core/bats-support
$ brew install bats-core/bats-core/bats-assert
$ brew install bats-core/bats-core/bats-file
```

### Running the Tests

To run the full test suite using the Taskfile:

```shell
$ task test
```

To run the tests directly with BATS:

```shell
$ bats --recursive scripts/tests
```

To run a specific test file:

```shell
$ bats scripts/tests/plan.bats
```

### Test Structure

All tests are in `scripts/tests/` and use the `.bats` file extension:

| File                           | Description                                              |
| :----------------------------- | :------------------------------------------------------- |
| `scripts/tests/validate.bats`  | Tests for `scripts/lib/validate.sh` functions            |
| `scripts/tests/plan.bats`      | Tests for `scripts/lib/plan.sh` functions                |
| `scripts/tests/apply.bats`     | Tests for `scripts/lib/apply.sh` functions               |
| `scripts/tests/templates.bats` | Tests for the gomplate templates in `scripts/templates/` |

Helper modules are in `scripts/tests/helpers/`:

| File                                  | Description                                    |
| :------------------------------------ | :--------------------------------------------- |
| `scripts/tests/helpers/mock.bash`     | `terraform` stub and environment setup helpers |
| `scripts/tests/helpers/fixtures.bash` | Terraform log output fixtures for use in tests |
