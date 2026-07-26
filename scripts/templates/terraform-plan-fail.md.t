## `terraform plan` for `{{ .Env.TF_NAME }}`

Terraform has attempted to generate the execution plan file (`terraform.tfplan`) for the configuration in [`{{ .Env.TF_NAME }}`][configuration] by running `terraform plan`, but **it has failed
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
{{- end }}**. The summary is as follows:

```plain
{{ printf "%d resources processed (plus %d data sources), with %d to add, %d to change, and %d to destroy."
    (ds "terraform").Summary.Resources
    (ds "terraform").Summary.DataSources
    (ds "terraform").Changes.Add
    (ds "terraform").Changes.Change
    (ds "terraform").Changes.Destroy
}}
```
{{  if gt (len (ds "terraform").Errors) 0 }}

> [!CAUTION]
> The following errors were identified by Terraform during the generation of this execution plan:
> ```plain
{{-   range (ds "terraform").Errors }}
> - {{ . }}
{{-   end }}
> ```
{{-  end }}

{{  if gt (len (ds "terraform").Warnings) 0 }}

> [!WARNING]
> The following warnings were identified by Terraform during the generation of this execution plan:
> ```plain
{{-   range (ds "terraform").Warnings }}
> - {{ . }}
{{-   end }}
> ```
{{- end }}
The details of the execution plan, breaking down all the individual additions, changes, and deletions, as identified by Terraform, is included below (click below to expand and view the `plan` log).

<details>
<summary>
  <code>terraform plan {{ .Env.TF_NAME }}</code> Output
</summary>

```plain
{{ (print (getenv "TF_PATH") "/.terraform/plan.trimmed.log") | file.Read | strings.TrimSpace }}
```

</details>

> [!IMPORTANT]
> The development of this execution plan by Terraform has failed with one or more errors. This workflow will proceed no further. **Please review the errors and then correct this Terraform configuration**, pushing the update which fixes these errors to this branch to re-create this plan. If, on the other hand, the error is believed to be transient, trigger the _Re-run failed jobs_ request in the failed GitHub Workflow job instead.

#### Terraform and Provider Versions

The following is a list of the versions of both Terraform and the Terraform providers required by either the configuration, or by the modules included, for this run:

```yaml
terraform: {{ (ds "terraform").Summary.Terraform }}
{{- if gt (len (ds "terraform").Summary.Providers) 0 }}
{{    toYAML (ds "terraform").Summary.Providers | strings.TrimSuffix "\n" }}
{{- end }}
```

[configuration]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/{{ if (ne .Env.TF_NAME ".") }}{{ .Env.TF_NAME }}/{{ end }}

{{- /* vim:set ft=markdown wrap linebreak tw=0: */ -}}
