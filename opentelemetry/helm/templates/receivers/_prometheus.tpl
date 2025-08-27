{{- define "mychart.receivers.prometheus" -}}
# Data sources: metrics
{{- include "mychart.receivers.prometheus.cluster" . -}}
{{- include "mychart.receivers.prometheus.tenant" . -}}
{{ end }}
