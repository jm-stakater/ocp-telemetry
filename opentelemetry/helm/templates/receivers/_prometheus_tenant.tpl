{{- define "mychart.receivers.prometheus.tenant" -}}
{{- range $_, $tenant := .Values.tenantRoles }}
{{- $tenantConfig := (index $.Values.tenants $tenant) }}
prometheus/{{ $tenant }}:
  config:
    {{- $global := (include "mychart.scrapeTiming" $tenantConfig.config) }}
    {{- if $global }}
    global: {{ $global | nindent 4 }}
    {{- end }}
    scrape_configs:
      - job_name: "kubernetes-pods-tenant-{{ $tenant }}"
        {{- include "mychart.apiScrapeConfig" $ | nindent 8 -}}
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: keep
            regex: .+
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: replace
            target_label: tenant
            regex: .+
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: drop
            regex: opentelemetry-collector-collector
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}
        metric_relabel_configs:
          - action: labeldrop
            regex: "(pod_template_hash)"

      - job_name: "kubernetes-service-endpoints-tenant-{{ $tenant }}"
        {{- include "mychart.apiScrapeConfig" $ | nindent 8 -}}
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: keep
            regex: .+
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: replace
            target_label: tenant
            regex: .+
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
      {{/*
      - job_name: "kubernetes-pods-{{ $tenant }}"
        {{- include "mychart.apiScrapeConfig" $ | indent 8 -}}
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: drop
            regex: .+
          {{- include "mychart.keepNamespaces" (list . $tenantConfig.namespaces) | nindent 10 }}
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: drop
            regex: opentelemetry-collector-collector
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}
        metric_relabel_configs:
          - action: labeldrop
            regex: "(pod_template_hash)"

      - job_name: "kubernetes-service-endpoints-{{ $tenant }}"
        {{- include "mychart.apiScrapeConfig" $ | indent 8 -}}
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: drop
            regex: .+
          {{- include "mychart.keepNamespaces" (list . $tenantConfig.namespaces) | nindent 10 }}
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
      */}}

      {{- if $.Values.config.blackbox }}
      - job_name: "kubernetes-services-tenant-{{ $tenant }}"
        metrics_path: /probe
        params:
          module: [http_2xx]
        kubernetes_sd_configs:
          - role: service
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: keep
            regex: .+
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: replace
            target_label: tenant
            regex: .+
          - source_labels: [__address__]
            target_label: __param_target
          - target_label: __address__
            replacement: {{ printf "%s:%d" $.Values.config.blackbox.endpoint ($.Values.config.blackbox.port | int) }}
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}


      - job_name: "kubernetes-ingresses-tenant-{{ $tenant }}"
        metrics_path: /probe
        params:
          module: [http_2xx]
        kubernetes_sd_configs:
          - role: ingress
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: keep
            regex: .+
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: replace
            target_label: tenant
            regex: .+
          - source_labels:
              [
                __meta_kubernetes_ingress_scheme,
                __address__,
                __meta_kubernetes_ingress_path,
              ]
            regex: (.+);(.+);(.+)
            replacement: ${1}://${2}${3}
            target_label: __param_target
          - target_label: __address__
            replacement: {{ printf "%s:%d" $.Values.config.blackbox.endpoint ($.Values.config.blackbox.port | int) }}
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_ingress_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}

      {{/*
      - job_name: "kubernetes-services-{{ $tenant }}"
        metrics_path: /probe
        params:
          module: [http_2xx]
        kubernetes_sd_configs:
          - role: service
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: drop
            regex: .+
          {{- include "mychart.keepNamespaces" (list . $tenantConfig.namespaces) | nindent 10 }}
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__address__]
            target_label: __param_target
          - target_label: __address__
            replacement: {{ printf "%s:%d" $.Values.config.blackbox.endpoint ($.Values.config.blackbox.port | int) }}
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}

      - job_name: "kubernetes-ingresses-{{ $tenant }}"
        metrics_path: /probe
        params:
          module: [http_2xx]
        kubernetes_sd_configs:
          - role: ingress
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace_label_stakater_com_tenant]
            action: drop
            regex: .+
          {{- include "mychart.keepNamespaces" (list . $tenantConfig.namespaces) | nindent 10 }}
          - source_labels: [__meta_kubernetes_ingress_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels:
              [
                __meta_kubernetes_ingress_scheme,
                __address__,
                __meta_kubernetes_ingress_path,
              ]
            regex: (.+);(.+);(.+)
            replacement: ${1}://${2}${3}
            target_label: __param_target
          - target_label: __address__
            replacement: {{ printf "%s:%d" $.Values.config.blackbox.endpoint ($.Values.config.blackbox.port | int) }}
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_ingress_label_(.+)
          {{- include "mychart.replaceLabels" $ | nindent 10 }}
      */}}
      {{- end -}}
{{- end }}
{{- end -}}