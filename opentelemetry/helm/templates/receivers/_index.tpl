{{- define "mychart.receivers" -}}
{{- include "mychart.receivers.jaeger" . -}}
{{- include "mychart.receivers.opencensus" . -}}
{{- include "mychart.receivers.otlp" . -}}
{{- include "mychart.receivers.prometheus" . -}}
{{- include "mychart.receivers.zipkin" . -}}
{{ end }}