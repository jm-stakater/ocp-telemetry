{{- define "mychart.processors.k8sattributes" -}}
k8sattributes:
  auth_type: "serviceAccount"
  extract:
    otel_annotations: true 
    metadata:
    - k8s.namespace.name
    - k8s.pod.name
    - k8s.pod.hostname
    - k8s.pod.ip
    - k8s.pod.start_time
    - k8s.pod.uid
    - k8s.replicaset.uid
    - k8s.replicaset.name
    - k8s.deployment.uid
    - k8s.deployment.name
    - k8s.daemonset.uid
    - k8s.daemonset.name
    - k8s.statefulset.uid
    - k8s.statefulset.name
    #- k8s.cronjob.uid
    - k8s.cronjob.name
    - k8s.job.uid
    - k8s.job.name
    - k8s.node.name
    - k8s.cluster.uid
    - service.namespace
    - service.name
    - service.version
    - service.instance.id
    annotations:
    - tag_name: k8s.namespace.annotation.stakater.com.current-tenant
      key: stakater.com/current-tenant
      from: namespace
    labels:
    - tag_name: k8s.namespace.label.stakater.com.tenant
      key: stakater.com/tenant
      from: namespace
  pod_association:
  - sources:
      # This rule associates all resources containing the 'k8s.pod.ip' attribute with the matching pods. If this attribute is not present in the resource, this rule will not be able to find the matching pod.
      - from: resource_attribute
        name: k8s.pod.ip
  - sources:
      # This rule associates all resources containing the 'k8s.pod.uid' attribute with the matching pods. If this attribute is not present in the resource, this rule will not be able to find the matching pod.
      - from: resource_attribute
        name: k8s.pod.uid
  - sources:
      # This rule will use the IP from the incoming connection from which the resource is received, and find the matching pod, based on the 'pod.status.podIP' of the observed pods
      - from: connection
{{ end }}