{{- define "mychart.exporters" -}}
{{- include "mychart.exporters.debug" . -}}
{{- include "mychart.exporters.tempo" . -}}
{{- include "mychart.exporters.lokistack" . -}}
{{- include "mychart.exporters.mimir" . -}}
{{ end }}