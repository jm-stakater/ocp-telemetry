# Grafana Instance Deployment

## What does it do

It spins Grafana (with a sidecar), deploys some datasources, couple of dashboards and a folder.

### What the sidecar does

First of, Grafana containers `readinessProbe` is changed to the sidecar. This is so that the sidecar can give the go ahead to the Service.

Sidecar business:

- collects the Tenant CRs for their names
- collects all groups, filters out so we only have the ones that matches the pattern of `<tenant name>-<role>-group-<hash>`
- wait's until Grafana api is up and running
- creates the organisations in Grafana
- gives the go ahead to `readinessProbe`


### How to use it with cluster domain

```bash
  OPENSHIFT_APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
  helm upgrade --install grafana-opentelemetry-instance  .\helm -n otel-monitoring --set route.domain="$OPENSHIFT_APPS_DOMAIN"
```
