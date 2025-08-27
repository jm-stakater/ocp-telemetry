{{- define "mychart.exporters.debug" -}}
# Data sources: traces, metrics, logs
{{- range $_, $value := list "metrics" "traces" "logs" }}
debug/{{ $value }}:
  # basic, normal or detailed
  verbosity: normal
{{- end }}
{{ end }}