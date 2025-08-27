{{- define "mychart.receivers.jaeger" -}}
# Data sources: traces
jaeger:
  protocols:
    grpc:
      endpoint: 0.0.0.0:14250
    thrift_binary:
      endpoint: 0.0.0.0:6832
    thrift_compact:
      endpoint: 0.0.0.0:6831
    thrift_http:
      endpoint: 0.0.0.0:14268
    {{- if index .Values "config" "receivers" "tls" }}
    tls: {{ include "mychart.tls" .Values.config.receivers.tls | nindent 6 -}}
    {{- end }}
{{ end }}