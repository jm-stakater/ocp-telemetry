{{- define "mychart.processors.batch" -}}
# Batch processor settings optimized for high-volume log ingestion
batch:
  timeout: 10s
  send_batch_size: 1024  # Reduced from 8192
  send_batch_max_size: 2048  # Reduced from 16384
{{ include "mychart.processors.batch_metrics" . }}
{{ end }}

{{- define "mychart.processors.batch_metrics" -}}
# Smaller batches for metrics to avoid HTTP 413 errors
batch/metrics:
  timeout: 5s
  send_batch_size: 512
  send_batch_max_size: 1024
{{ end }}