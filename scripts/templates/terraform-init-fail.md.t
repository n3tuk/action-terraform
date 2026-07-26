## `terraform init` for `{{ .Env.TF_NAME }}`

Terraform has attempted to initialise the configuration in [`{{ .Env.TF_NAME }}`][configuration], but **this has failed
{{- if gt (len (ds "terraform").Errors) 0 -}}
{{ " " }}with {{ len (ds "terraform").Errors }} error{{ if ne (len (ds "terraform").Errors) 1 }}s{{ end }}
{{- end -}}
{{- if and (gt (len (ds "terraform").Errors) 0) (gt (len (ds "terraform").Warnings) 0) -}}
, and
{{- end -}}
{{- if gt (len (ds "terraform").Warnings) 0 -}}
{{ " " }}with {{ len (ds "terraform").Warnings }} warning{{ if ne (len (ds "terraform").Warnings) 1 }}s{{ end -}}
{{- end -}}
{{- if and (eq (len (ds "terraform").Errors) 0) (eq (len (ds "terraform").Warnings) 0) -}}
{{ " " }}with no errors or warnings (please review the output below for any issues identified by Terraform)
{{- end }}**:
{{  if gt (len (ds "terraform").Errors) 0 }}
> [!CAUTION]
> The following errors were identified by Terraform during the initialisation of this configuration:
> ```plain
{{    range (ds "terraform").Errors -}}
> - {{ . }}
{{-   end }}
> ```
{{-  end }}
{{  if gt (len (ds "terraform").Warnings) 0 }}
> [!WARNING]
> The following warnings were identified by Terraform during the initialisation of this configuration:
> ```plain
{{    range (ds "terraform").Warnings -}}
> - {{ . }}
{{-   end }}
> ```
{{- end }}
The full log showing the initialisation of the configuration by Terraform is included below (click below to expand and view the `init` log):

<details>
<summary>
  <code>terraform init {{ .Env.TF_NAME }}</code> Output
</summary>

```terraform
{{ (print (getenv "TF_PATH") "/.terraform/init.log") | file.Read | strings.TrimSpace }}
```

</details>

> [!IMPORTANT]
> No further actions can be applied against this configuration by Terraform. **Please review the errors reported and correct this Terraform configuration**, pushing the update which fixes these (if the error is not believed to be transient) before running the workflow again.

[configuration]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/{{ if (ne .Env.TF_NAME ".") }}{{ .Env.TF_NAME }}/{{ end }}

{{- /* vim:set ft=markdown wrap linebreak tw=0: */}}
