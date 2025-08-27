{{/*Expand the name of the chart.*/}}
{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "mychart.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mychart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mychart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mychart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- /*
mychart.util.merge will merge two YAML templates and output the result.
This takes an array of three values:
- the top context
- the template name of the overrides (destination)
- the template name of the base (source)
*/}}
{{- define "mychart.util.merge" -}}
{{- $top := first . -}}
{{- $overrides := fromYaml (include (index . 1) $top) | default (dict ) -}}
{{- $tpl := fromYaml (include (index . 2) $top) | default (dict ) -}}
{{- toYaml (merge $overrides $tpl) -}}
{{- end -}}

{{/*
Create TLS node
*/}}
{{- define "mychart.tls" -}}
{{- if index . "cert_file" -}}
cert_file: {{ .cert_file }}
{{ end -}}
{{- if index . "key_file" -}}
key_file: {{ .key_file }}
{{ end -}}
{{- if index . "ca_file" -}}
ca_file: {{ .ca_file }}
{{ end -}}
{{- if index . "reload_interval" -}}
reload_interval: {{ .reload_interval }}
{{ end -}}
{{- if index . "insecure_skip_verify" -}}
insecure_skip_verify: {{ .insecure_skip_verify }}
{{- end -}}
{{- end -}}

{{/*
Scrape values
*/}}
{{- define "mychart.apiScrapeConfigScheme" }}
{{- if ((.Values.config).internal).scheme -}}
scheme: {{ .Values.config.internal.scheme | default "https" }}
{{- end }}
{{- include "mychart.apiScrapeConfig" . }}
{{- end }}

{{/*
Scrape values
*/}}
{{- define "mychart.apiScrapeConfig" }}
tls_config: {{ include "mychart.tls" .Values.config.tls | nindent 2 }}
{{- include "mychart.auth" .Values.config }}
{{- end }}

{{/*
Scrape timeout & intervals
*/}}
{{- define "mychart.auth" }}
{{- if ((.auth).authenticator) -}}
auth: {{ include "mychart.auth" .auth | nindent 2 }}
{{- end -}}
{{- if ((.authorization).credentials_file) }}
authorization: {{ include "mychart.auth" .authorization | nindent 2 }}
{{- end -}}
{{- if (.authenticator) -}}
authenticator: {{ .authenticator }}
{{- end -}}
{{- if (.credentials_file) -}}
credentials_file: {{ .credentials_file }}
{{- end }}
{{ end }}

{{/*
Scrape timeout & intervals
*/}}
{{- define "mychart.scrapeTiming" -}}
{{- if .keep_dropped_targets -}}
{{/* Limit per scrape config on the number of targets dropped by relabeling
   * that will be kept in memory. 0 means no limit. */}}
{{- printf "keep_dropped_targets: %d" (.keep_dropped_targets | int) }}
{{ end -}}
{{- if .evaluation_interval -}}
{{/* How frequently to evaluate rules. */}}
{{- printf "evaluation_interval: %s" .evaluation_interval }}
{{ end -}}
{{- if .scrape_interval -}}
{{/* How frequently to scrape targets by default.
   * [ scrape_interval: <duration> | default = 1m ] */}}
{{- printf "scrape_interval: %s" .scrape_interval }}
{{ end -}}
{{- if .scrape_timeout -}}
{{/* How long until a scrape request times out.
   * It cannot be greater than the scrape interval.
   * [ scrape_timeout: <duration> | default = 10s ] */}}
{{- printf "scrape_timeout: %s" .scrape_timeout }}
{{ end -}}
{{ end }}

{{/*
Action on certain namespaces
*/}}
{{- define "mychart.actionNamespaces" -}}
{{- $list := index . 0 -}}
{{- $action := index . 1 -}}
- source_labels: [__meta_kubernetes_namespace]
  regex: {{ $list | join "|" | quote }}
  action: {{ $action }}
{{- end }}

{{/*
Ignore certain namespaces
*/}}
{{- define "mychart.ignoreNamespaces" -}}
{{ include "mychart.actionNamespaces" (list .Values.config.ignore.namespace "drop") }}
{{- end }}

{{/*
Keep certain namespaces
*/}}
{{- define "mychart.keepNamespaces" -}}
{{- $top := index . 0 -}}
{{- $namespaces := index . 1 -}}
{{ include "mychart.actionNamespaces" (list $namespaces "keep") }}
{{- end }}

{{/*
DRY Replace Labels
*/}}
{{- define "mychart.replaceLabels" -}}
{{- range $key, $value := .Values.config.replaceLabels -}}
- source_labels: [{{ $key }}]
  action: replace
  target_label: {{ $value }}
{{ end -}}
{{- end }}

