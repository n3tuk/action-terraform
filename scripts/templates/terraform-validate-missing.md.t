## `terraform validate` for `{{ .Env.TF_NAME }}`

Terraform attempted to find example configurations under the [`examples/`][examples] directory to initialise and validate the Terraform module at [`{{ .Env.TF_NAME }}`][module], but **it has failed as no example configurations could be found**.

> [!CAUTION]
> A Terraform module cannot be directly validated as providers must be initialised in the root configuration. **Please add an example configuration to the `examples/` directory of this repository, and then push this change to the branch to re-trigger this validation**.

[module]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/
[examples]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/examples/

{{- /* vim:set ft=markdown wrap linebreak tw=0: */ -}}
