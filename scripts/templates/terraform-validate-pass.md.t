## `terraform validate` for `{{ .Env.TF_NAME }}`

Terraform has successfully initialised and validated
{{- if (eq (getenv "TF_MODULE" "false") "true") -}}
 {{ " " }}the example module configuration(s) provided under the [`examples/`][examples] directory for the module [`.`][module]
{{- else -}}
 {{ " " }}the configuration in [`{{ .Env.TF_NAME }}`][configuration]
{{- end }} by running `terraform init` and `terraform validate`.

#### Terraform and Provider Versions

The following is a list of the versions of both Terraform and the Terraform providers required by the configuration and the modules it includes, for this run:

```yaml
terraform: {{ (ds "terraform").Summary.Terraform }}
{{- if gt (len (ds "terraform").Summary.Providers) 0 }}
{{    toYAML (ds "terraform").Summary.Providers | strings.TrimSuffix "\n" }}
{{- end }}
```

{{  if (eq (getenv "TF_MODULE" "false") "true") -}}
[module]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/
[examples]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/examples/
{{- else -}}
[configuration]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/{{ if (ne .Env.TF_NAME ".") }}{{ .Env.TF_NAME }}/{{ end }}
{{- end }}

{{- /* vim:set ft=markdown wrap linebreak tw=0: */ -}}
