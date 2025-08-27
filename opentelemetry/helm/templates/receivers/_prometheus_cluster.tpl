{{- define "mychart.receivers.prometheus.cluster" }}
prometheus/cluster:
  config:
    global: {{- include "mychart.scrapeTiming" .Values.config.global | nindent 6 }}
    scrape_configs:
      - job_name: 'otel-collector'
        {{- include "mychart.scrapeTiming" .Values.config.openshift | nindent 8 -}}
        static_configs:
        - targets: [ '0.0.0.0:8888' ]
        relabel_configs:
          {{- include "mychart.replaceLabels" . | nindent 10 }}
        metric_relabel_configs:
        - action: labeldrop
          regex: (id|name)
        - action: labelmap
          regex: label_(.+)
          replacement: $$1

      {{- /*
        @see https://github.com/prometheus/prometheus/blob/release-3.5/documentation/examples/prometheus-kubernetes.yml
      */}}
      - job_name: "kubernetes-apiservers"
        kubernetes_sd_configs:
          - role: endpoints
        {{- include "mychart.apiScrapeConfigScheme" . | nindent 8 -}}
        # Keep only the default/kubernetes service endpoints for the https port. This
        # will add targets for each API server which Kubernetes adds an endpoint to
        # the default/kubernetes service.
        relabel_configs:
          - source_labels:
              [
                __meta_kubernetes_namespace,
                __meta_kubernetes_service_name,
                __meta_kubernetes_endpoint_port_name,
              ]
            action: keep
            regex: default;kubernetes;https
          {{- include "mychart.replaceLabels" . | nindent 10 }}

      # Scrape config for nodes (kubelet).
      - job_name: "kubernetes-nodes"
        {{- include "mychart.apiScrapeConfigScheme" . | nindent 8 -}}
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          {{- include "mychart.replaceLabels" . | nindent 10 }}

      # Scrape config for Kubelet cAdvisor.
      - job_name: "kubernetes-cadvisor"
        {{- include "mychart.apiScrapeConfigScheme" . | nindent 8 -}}
        metrics_path: /metrics/cadvisor
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          {{- include "mychart.replaceLabels" . | nindent 10 }}
        metric_relabel_configs:
          # Drop high-cardinality labels from cAdvisor to reduce series count.
          - action: labeldrop
            regex: "(id|name|image)"

      # Scrape config for kube-state-metrics.
      # This job specifically targets the kube-state-metrics service, which provides
      # metrics like 'kube_namespace_created'. It bypasses the namespace ignore rules.
      - job_name: "kube-state-metrics"
        {{- include "mychart.apiScrapeConfigScheme" . | nindent 8 -}}
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          # Find the kube-state-metrics service by its standard label.
          - source_labels: [__meta_kubernetes_service_label_k8s_app]
            action: keep
            regex: kube-state-metrics
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          {{- include "mychart.replaceLabels" . | nindent 10 }}

      # OpenShift-specific scrape config for internal services
      - job_name: "openshift-internal-services"
        {{- include "mychart.apiScrapeConfigScheme" . | nindent 8 -}}
        kubernetes_sd_configs:
          - role: endpoints
            namespaces:
              names:
              - openshift-etcd
              - openshift-multus
              - openshift-monitoring
              - kube-system
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name]
            action: keep
            regex: (etcd|network-metrics-service)
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          {{- include "mychart.replaceLabels" . | nindent 10 }}
{{- end }}