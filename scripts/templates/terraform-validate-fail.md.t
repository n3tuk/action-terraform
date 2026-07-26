## `terraform validate` for `{{ .Env.TF_NAME }}`

Terraform has attempted to initialise and validate
{{- if (eq (getenv "TF_MODULE" "false") "true") -}}
 {{ " " }}the example module configurations provided in [`.`][module]
{{- else }}
 {{ " " }}the configuration in [`{{ .Env.TF_NAME }}`][configuration]
{{- end }}, but **it has failed
{{- if gt (len (ds "terraform").Errors) 0 -}}
 {{ " " }}with {{ len (ds "terraform").Errors }} error{{ if ne (len (ds "terraform").Errors) 1 }}s{{ end }}
{{- end -}}
{{- if and (gt (len (ds "terraform").Errors) 0) (gt (len (ds "terraform").Warnings) 0) -}}
, and
{{- end -}}
{{- if gt (len (ds "terraform").Warnings) 0 -}}
 {{ " " }}with {{ len (ds "terraform").Warnings }} warning{{ if ne (len (ds "terraform").Warnings) 1 }}s{{ end }}
{{- end -}}
{{- if and (eq (len (ds "terraform").Errors) 0) (eq (len (ds "terraform").Warnings) 0) -}}
 {{ " " }}with no errors or warnings (please review the output below for any issues identified by Terraform)
{{- end }}**.

{{- if gt (len (ds "terraform").Errors) 0 }}

> [!CAUTION]
> The following errors were reported during validation:
> ```plain
{{-   range (ds "terraform").Errors }}
> - {{ . }}
{{-   end }}
> ```
{{- end }}

{{-  if gt (len (ds "terraform").Warnings) 0 }}

> [!WARNING]
> The following warnings were reported during validation:
> ```plain
{{-   range (ds "terraform").Warnings }}
> - {{ . }}
{{-   end }}
> ```
{{- end }}

<details>
<summary>
  <code>terraform validate {{ .Env.TF_NAME }}</code> Output
</summary>

```plain
{{ (print (getenv "TF_PATH") "/.terraform/validate.log") | file.Read | strings.TrimSpace }}
```

</details>

> [!IMPORTANT]
> The validation of this configuration by Terraform has failed with one or more errors. This workflow will proceed no further. **Please review the errors and then correct this Terraform configuration**, pushing the update which fixes these errors to this branch to re-trigger this validation. If, on the other hand, the error is believed to be transient, trigger the _Re-run failed jobs_ request in the failed GitHub Workflow job instead.

#### Terraform and Provider Versions

The following is a list of the versions of both Terraform and the Terraform providers required by the configuration and the modules it includes, for this run:

```yaml
terraform: {{ (ds "terraform").Summary.Terraform }}
{{- if gt (len (ds "terraform").Summary.Providers) 0 }}
{{    toYAML (ds "terraform").Summary.Providers | strings.TrimSuffix "\n" }}
{{- end }}
```

{{- if (eq (getenv "TF_MODULE" "false") "true") -}}
[module]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/
{{- else -}}
[configuration]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/{{ if (ne .Env.TF_NAME ".") }}{{ .Env.TF_NAME }}/{{ end }}
{{- end }}

{{- /* vim:set ft=markdown wrap linebreak tw=0: */ -}}
