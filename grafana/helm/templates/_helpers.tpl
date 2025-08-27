{{/*
Expand the name of the chart.
*/}}
{{- define "grafana-instance.name" -}}
{{- /* default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" */}}
{{- default .Chart.Name .Values.grafana.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "grafana-instance.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- /*$name := default .Chart.Name .Values.nameOverride*/}}
{{- $name := default .Chart.Name .Values.grafana.name }}
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
{{- define "grafana-instance.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "grafana-instance.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "grafana-instance.serviceAccountName" -}}
{{- if and .Values.serviceAccount .Values.serviceAccount.create }}
{{- default (include "grafana-instance.fullname" .) .Values.serviceAccount.name }}
{{- else if .Values.grafana.name }}
{{- printf "%s-sa" .Values.grafana.name }}
{{- else }}
{{- default "default" (.Values.serviceAccount).name }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "grafana-instance.labels" -}}
helm.sh/chart: {{ include "grafana-instance.chart" . }}
{{ include "grafana-instance.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "grafana-instance.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grafana-instance.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Match Selector labels
*/}}
{{- define "grafana-instance.instanceSelector" -}}
instanceSelector:
  matchLabels: {{ toYaml .Values.grafana.instance.labels | nindent 6 }}
{{- end }}

{{/*
Get the cluster domain
*/}}
{{- define "grafana-instance.clusterDomain" -}}
{{- $clusterDomain := "" -}}
{{- if .Values.grafana.domain -}}
{{- $clusterDomain = .Values.grafana.domain -}}
{{- else -}}
{{- $clusterDomain = ((lookup "config.openshift.io/v1" "DNS" "" "cluster" ).spec).baseDomain -}}
{{- end -}}
{{- if not $clusterDomain -}}
{{- fail "Unable to find Cluster Domain" -}}
{{- end -}}
{{- $clusterDomain -}}
{{- end -}}

{{/*
Expand the domainname to grafana
*/}}
{{- define "grafana-instance.domain" -}}
{{- printf "%s-route-%s.apps.%s" (default (include "grafana-instance.name" .) .Values.routeName) (include "grafana-instance.namespace" .) (include "grafana-instance.clusterDomain" .) }}
{{- end }}

{{/*
Common Grafana values
*/}}
{{- define "grafana-instance.commonValues" -}}
{{- include "grafana-instance.instanceSelector" . }}
allowCrossNamespaceImport: true
resyncPeriod: {{ .Values.resyncPeriod | default "10m0s" }}
{{- end }}

{{/*
Create volume based on files
*/}}
{{- define "grafana-instance.build-volumes" -}}
{{- $top := index . 0 -}}
{{- $key := (index . 1) | default "" -}}
{{- if eq $key "" -}}
{{- fail "Missing second index in parameters" -}}
{{- end -}}
{{- $dirpath := (printf "json/%s/*" $key) -}}
{{- $files := ($top.Files.Glob $dirpath) -}}
{{- if $files -}}
{{- $sources := (list) -}}
{{- range $path, $_ := $files }}
{{- $name := (printf "%s-%s-json" $key (base $path | trimSuffix ".json")) -}}
{{- $map := dict "name" $name "optional" true -}}
{{- $confmap := dict "configMap" $map -}}
{{- $sources = append $sources $confmap -}}
{{- end -}}
{{- $projected := dict "sources" $sources -}}
{{- $dict := dict "name" (printf "%s-json" $key) "projected" $projected -}}
{{- $dict | toJson -}}
{{- end -}}
{{- end -}}

{{/*
Create volumemounts based on files
*/}}
{{- define "grafana-instance.build-volumemounts" -}}
{{- $top := index . 0 -}}
{{- $key := (index . 1) | default "" -}}
{{- if eq $key "" -}}
{{- fail "Missing second index in parameters" -}}
{{- end -}}
{{- $dirpath := (printf "json/%s/*" $key) -}}
{{- if ($top.Files.Glob $dirpath) -}}
{{- $dict := dict "mountPath" (printf "/etc/grafana/provisioning/%s" $key) "name" (printf "%s-json" $key) "readOnly" true -}}
{{- $dict | toJson -}}
{{- end -}}
{{- end -}}

{{/*
Create provisioning volume based on files
*/}}
{{- define "grafana-instance.provision-volumes" -}}
{{- $list := (list) }}
{{- $dashboards := ((include "grafana-instance.build-volumes" (list . "dashboards")) | default "{}" | fromJson) -}}
{{- if $dashboards -}}
{{- $list = append $list $dashboards -}}
{{- end -}}
{{- $datasources := ((include "grafana-instance.build-volumes" (list . "datasources")) | default "{}" | fromJson) -}}
{{- if $datasources -}}
{{- $list = append $list $datasources -}}
{{- end -}}
{{- $plugins := ((include "grafana-instance.build-volumes" (list . "plugins")) | default "{}" | fromJson) -}}
{{- if $plugins -}}
{{- $list = append $list $plugins -}}
{{- end -}}
{{- $notifiers := ((include "grafana-instance.build-volumes" (list . "notifiers")) | default "{}" | fromJson) -}}
{{- if $notifiers -}}
{{- $list = append $list $notifiers -}}
{{- end -}}
{{- $alerting := ((include "grafana-instance.build-volumes" (list . "alerting")) | default "{}" | fromJson) -}}
{{- if $alerting -}}
{{- $list = append $list $alerting -}}
{{- end -}}
{{- $list | toYaml }}
{{- end }}

{{/*
Create provisioning volumemounts based on files
*/}}
{{- define "grafana-instance.provision-volumemounts" -}}
{{- $list := (list) }}
{{- $dashboards := ((include "grafana-instance.build-volumemounts" (list . "dashboards")) | default "{}" | fromJson) -}}
{{- if $dashboards -}}
{{- $list = append $list $dashboards -}}
{{- end -}}
{{- $datasources := ((include "grafana-instance.build-volumemounts" (list . "datasources")) | default "{}" | fromJson) -}}
{{- if $datasources -}}
{{- $list = append $list $datasources -}}
{{- end -}}
{{- $plugins := ((include "grafana-instance.build-volumemounts" (list . "plugins")) | default "{}" | fromJson) -}}
{{- if $plugins -}}
{{- $list = append $list $plugins -}}
{{- end -}}
{{- $notifiers := ((include "grafana-instance.build-volumemounts" (list . "notifiers")) | default "{}" | fromJson) -}}
{{- if $notifiers -}}
{{- $list = append $list $notifiers -}}
{{- end -}}
{{- $alerting := ((include "grafana-instance.build-volumemounts" (list . "alerting")) | default "{}" | fromJson) -}}
{{- if $alerting -}}
{{- $list = append $list $alerting -}}
{{- end -}}
{{- $list | toYaml }}
{{- end }}
