# 🎭 Dex IdP Deployment

Welcome to **Dex** – your friendly neighborhood identity broker.

## 🚀 What’s going on here?

In this cluster, Dex plays the role of **middle-manager for identities**:

* OpenShift already talks to **Active Directory via LDAP**.
* Dex takes that info and says: *“Cool, I’ll explain this to the apps.”*
* Your apps don’t need to understand LDAP, AD, or corporate wizardry — they just ask Dex.

Think of Dex as the **universal adapter plug** in the messy world of authentication.

## 📦 What’s included?

* **Dex**: The broker.
* **Config**: How Dex learns to trust OpenShift (which trusts AD).
* **Deployment bits**: YAML/Helm to make it run without rage-quitting.

## 🛠 How to deploy

1. Deploy Dex into OpenShift (manifests or Helm — choose your weapon).
2. Configure Dex to treat OpenShift as its “connector.”
3. Point your apps to Dex as their OIDC provider.
4. Enjoy not wiring every app directly to LDAP. 🎉

## 🎭 Why Dex?

Because without it, every app would need to understand LDAP, Kerberos, and whatever AD mood swings are happening today.
With Dex, apps just speak OIDC — life is good.

## 🧹 Cleanup

`kubectl delete -f dex.yaml`
(or if you’re really done, unplug AD and watch chaos ensue — not recommended).

## Deploy med cluster domain

```bash
  OPENSHIFT_APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
  helm upgrade --install dex-instance .\helm -n dex-instance --set route.domain="$OPENSHIFT_APPS_DOMAIN"
```
