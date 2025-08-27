{{- define "mychart.processors" -}}
{{- include "mychart.processors.batch" . -}}
{{- include "mychart.processors.k8sattributes" . -}}
{{- include "mychart.processors.memory_limiter" . -}}
{{- include "mychart.processors.resource" . -}}
{{- include "mychart.processors.transform" . -}}
{{- include "mychart.processors.resourcedetection" . -}}
{{- include "mychart.processors.routing" . -}}
{{ end }}