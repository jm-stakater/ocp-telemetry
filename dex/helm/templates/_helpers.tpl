{{/*
Get the cluster domain
*/}}
{{- define "dex.clusterDomain" -}}
{{- $clusterDomain := "" -}}
{{- if .Values.clusterDomain -}}
{{- $clusterDomain = .Values.clusterDomain -}}
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
{{- define "dex.domain" -}}
{{- printf "%s-%s.apps.%s" .Values.routeName (include "dex.namespace" .) (include "dex.clusterDomain" .) }}
{{- end }}
