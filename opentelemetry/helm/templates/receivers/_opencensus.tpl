{{- define "mychart.receivers.opencensus" -}}
# Data sources: traces, metrics
opencensus:
  endpoint: 0.0.0.0:55678
  {{- if .Values.config.receivers.tls }}
  tls: {{ include "mychart.tls" .Values.config.receivers.tls | nindent 4 -}}
  {{- end }}
{{ end }}