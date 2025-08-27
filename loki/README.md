# RedHat Loki Instance

https://github.com/openshift/loki

tenants.mode: openshift-logging
Treats each OpenShift Project as a tenant, and restricts access to logs based on users' namespace access.

The S3 secret used by Loki must contain the following:
bucketnames: loki
endpoint: http://s3.openshift-storage.svc
access_key_id: your-access-key
access_key_secret: your-secret-key
