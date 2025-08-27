{{- define "mychart.exporters.lokistack" -}}
# Loki Data sources: logs
{{- range $_, $value := .Values.tenantRoles }}
otlphttp/lokistack-{{ $value }}:
  endpoint: {{ printf "https://loki-gateway-http.loki-instance.svc:8080/api/logs/v1/%s/otlp" $value }}
  encoding: json
  timeout: 30s
  retry_on_failure:
    enabled: true
    initial_interval: 5s
    max_interval: 30s
    max_elapsed_time: 300s
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