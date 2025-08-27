# Grafana Instance Deployment


### How to use it with cluster domain

```bash
  OPENSHIFT_APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
  helm upgrade --install grafana-opentelemetry-instance  .\helm -n otel-monitoring --set route.domain="$OPENSHIFT_APPS_DOMAIN"
```
