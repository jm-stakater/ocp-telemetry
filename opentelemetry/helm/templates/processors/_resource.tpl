{{- define "mychart.processors.resource" -}}
resource:
  attributes:
    - key: kubernetes.namespace_name
      from_attribute: k8s.namespace.name
      action: upsert
    - key: kubernetes.pod_name
      from_attribute: k8s.pod.name
      action: upsert
    - key: kubernetes.container_name
      from_attribute: k8s.container.name
      action: upsert
    - key: log_type
      value: application
      action: upsert
{{ end }}