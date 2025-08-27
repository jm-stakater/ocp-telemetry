{{- define "mychart.exporters.tempo" -}}
# OTLP Data sources: traces, metrics, logs
{{- range $_, $value := .Values.tenantRoles }}
otlphttp/tempo-{{ $value }}:
  endpoint: http://tempo-tempo.tempo-instance.svc:4318
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