## `terraform apply` for `{{ .Env.TF_NAME }}/terraform.tfplan`

Terraform has attempted to apply the execution plan file (`terraform.tfplan`) for the configuration in [`{{ .Env.TF_NAME }}`][configuration] by running `terraform apply`, but **it has
{{- if (or (gt (ds "terraform").Changes.Added 0)
           (or (gt (ds "terraform").Changes.Changed 0)
               (gt (ds "terraform").Changes.Destroyed 0))) }}
 partially
{{- else }}
 wholly
{{- end }} failed
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
{{- end }}**.
{{- if (or (gt (ds "terraform").Changes.Added 0)
           (or (gt (ds "terraform").Changes.Changed 0)
               (gt (ds "terraform").Changes.Destroyed 0))) -}}
{{ " " }}The summary of any changes is as follows:

```plain
{{    printf "%d resources added, %d changed, and %d destroyed."
       (ds "terraform").Changes.Added
       (ds "terraform").Changes.Changed
       (ds "terraform").Changes.Destroyed }}
```
{{  end }}

{{  if gt (len (ds "terraform").Errors) 0 }}

> [!CAUTION]
> The following errors were reported by Terraform during the application of this execution plan:
> ```plain
{{-   range (ds "terraform").Errors }}
> - {{ . }}
{{-   end }}
> ```
{{-  end }}

{{  if gt (len (ds "terraform").Warnings) 0 }}

> [!WARNING]
> The following warnings were reported by Terraform during the application of this execution plan:
> ```plain
{{-   range (ds "terraform").Warnings }}
> - {{ . }}
{{-   end }}
> ```
{{- end }}
The full log showing all the changes applied by Terraform is included
below (click below to expand and view the apply log):

<details>
<summary>
  <code>terraform apply {{ .Env.TF_NAME }}/terraform.tfplan</code> Output
</summary>

```plain
{{ (print (getenv "TF_PATH") "/.terraform/apply.log") | file.Read | strings.TrimSpace }}
```

</details>

> [!IMPORTANT]
> **Please review the warning and error messages and then correct the Terraform configuration**, pushing an update to fix these processes through a new Pull Request. If, on the other hand, the error is believed to be transient, **and no changes have been made to any resources nor the state file** (which would invalidate the `terraform.tfplan` execution plan), trigger the _Re-run failed jobs_ request in the failed GitHub Workflow job to re-apply this plan. If, however, any changes have been made, a full `plan-and-apply` run must be triggered [manually on the workflow][workflow-dispatch] to create a new execution plan and apply it.

[configuration]: https://github.com/{{ .Env.GITHUB_REPOSITORY }}/tree/{{ getenv "GITHUB_HEAD_REF" }}/{{ if (ne .Env.TF_NAME ".") }}{{ .Env.TF_NAME }}/{{ end }}
[workflow-dispatch]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

{{- /* vim:set ft=markdown wrap linebreak tw=0: */ -}}
