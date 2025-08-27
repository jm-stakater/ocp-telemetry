{{- define "mychart.processors.memory_limiter" -}}
memory_limiter:
  {{- if .Values.config.processors.memory_limiter.check_interval }}
  check_interval: {{ .Values.config.processors.memory_limiter.check_interval | quote }}
  {{- end }}
  {{- if .Values.config.processors.memory_limiter.limit_mib }}
  # Hard limit will be set to 4000 MiB.
  limit_mib: {{ .Values.config.processors.memory_limiter.limit_mib | int }}
  {{- end }}
  {{- if .Values.config.processors.memory_limiter.spike_limit_mib }}
  # Soft limit will be set to 4000 - 500 = 3500 MiB.
  spike_limit_mib: {{ .Values.config.processors.memory_limiter.spike_limit_mib | int }}
  {{- end }}
  {{- if .Values.config.processors.memory_limiter.limit_percentage }}
  # Hard limit will be set to 1000 * 0.80 = 800 MiB.
  limit_percentage: {{ .Values.config.processors.memory_limiter.limit_percentage | int }}
  {{- end }}
  {{- if .Values.config.processors.memory_limiter.spike_limit_percentage }}
  # Soft limit will be set to 1000 * 0.80 - 1000 * 0.20 = 1000 * 0.60 = 600 MiB.
  spike_limit_percentage: {{ .Values.config.processors.memory_limiter.spike_limit_percentage | int }}
  {{- end }}
{{ end }}