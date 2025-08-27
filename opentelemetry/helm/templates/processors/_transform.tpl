{{- define "mychart.processors.transform" -}}
{{- include "mychart.processors.transform_logs" . -}}
{{- include "mychart.processors.transform_tenant" . -}}
{{ end }}

{{- define "mychart.processors.transform_logs" -}}
transform/logs:
  log_statements:
    - context: log
      statements:
        - set(attributes["level"], ConvertCase(severity_text, "lower"))
        - set(attributes["span_id"], attributes["otelSpanID"]) where attributes["otelSpanID"] != nil
        - set(attributes["trace_id"], attributes["otelTraceID"]) where attributes["otelTraceID"] != nil
        - set(attributes["service_name"], attributes["otelServiceName"]) where attributes["otelServiceName"] != nil
{{ end }}

{{- define "mychart.processors.transform_tenant" -}}
transform/tenant:
  log_statements:
    - context: resource
      statements: {{- include "mychart.processors.transform_tenant.build" . | nindent 6 }}
  trace_statements:
    - context: resource
      statements: {{- include "mychart.processors.transform_tenant.build" . | nindent 6 }}
  metric_statements:
    - context: resource
      statements: {{- include "mychart.processors.transform_tenant.build" . | nindent 6 }}
{{ end }}

{{/*
Tenant-aware processor transform
# kind: Namespace
# apiVersion: v1
# metadata:
#   labels:
#     stakater.com/tenant: observability
#   annotations:
#    stakater.com/current-tenant: observability
*/}}
{{- define "mychart.processors.transform_tenant.build" -}}
{{- $attribute := "tenant" -}}
{{- $label := "k8s.namespace.label.stakater.com.tenant" -}}
{{- $annotation := "k8s.namespace.annotation.stakater.com.current-tenant" -}}
{{- /* Use namespace label for tenant (highest priority) */ -}}
- set(attributes[{{ $attribute | quote }}], attributes[{{ $label | quote }}]) where attributes[{{ $label | quote }}] != nil
{{- /* Fallback to namespace annotation if label not found and tenant attribute is not yet set */}}
- set(attributes[{{ $attribute | quote }}], attributes[{{ $annotation | quote }}]) where attributes[{{ $annotation | quote }}] != nil and attributes[{{ $attribute | quote }}] == nil
{{- /* Final fallback to default tenant if attribute is still not set */}}
- set(attributes[{{ $attribute | quote }}], {{ .Values.tenantDefault | default "" | quote }}) where attributes[{{ $attribute | quote }}] == nil
{{- end }}
