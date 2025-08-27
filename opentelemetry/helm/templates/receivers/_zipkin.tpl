{{- define "mychart.receivers.zipkin" -}}
# Data sources: traces
zipkin:
  endpoint: 0.0.0.0:9411
  {{- if index .Values "config" "receivers" "tls" }}
  tls: {{ include "mychart.tls" .Values.config.receivers.tls | nindent 4 -}}
  {{- end }}
{{ end }}