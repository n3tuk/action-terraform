## `terraform plan` for `{{ .Env.TF_NAME }}`

Terraform has generated an execution plan file (`terraform.tfplan`) for the configuration in [`{{ .Env.TF_NAME }}`][configuration] by running `terraform plan`. The summary is as follows:

```plain
{{ printf "%d resources processed (plus %d data sources), with %d to add, %d to change, and %d to destroy."
    (ds "terraform").Summary.Resources
    (ds "terraform").Summary.DataSources
    (ds "terraform").Changes.Add
    (ds "terraform").Changes.Change
    (ds "terraform").Changes.Destroy
}}
```

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
> Please review this execution plan to ensure that the changes identified are what was expected.

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
