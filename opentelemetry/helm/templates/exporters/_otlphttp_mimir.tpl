{{- define "mychart.exporters.mimir" -}}
# Mimir Data sources: metrics
{{- range $_, $value := .Values.tenantRoles }}
otlphttp/mimir-{{ $value }}:
  endpoint: http://mimir-instance-nginx.mimir-instance.svc:80/otlp
  disable_keep_alives: false
  headers:
    X-Scope-OrgID: {{ $value }}
  {{- if index $.Values "config" "exporters" "tls" }}
  tls: {{ include "mychart.tls" $.Values.config.exporters.tls | nindent 4 -}}
  {{- end }}
  {{- if index $.Values "config" "exporters" "auth" }}
  auth: {{ $.Values.config.exporters.auth | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{ end }}