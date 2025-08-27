{{- define "mychart.receivers.otlp" -}}
# Data sources: traces, metrics, logs
otlp:
  protocols:
    grpc:
      endpoint: 0.0.0.0:4317
      {{- if index .Values "config" "receivers" "tls" }}
      tls: {{ include "mychart.tls" .Values.config.receivers.tls | nindent 8 -}}
      {{- end }}
    http:
      endpoint: 0.0.0.0:4318
      {{- if index .Values "config" "receivers" "tls" }}
      tls: {{ include "mychart.tls" .Values.config.receivers.tls | nindent 8 -}}
      {{- end }}
      {{- if .Values.config.receivers.auth }}
      auth: {{ .Values.config.receivers.auth | toYaml | nindent 8 }}
      {{- end }}
{{ end }}