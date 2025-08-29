import os
import time
import logging
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

import requests
from kubernetes import client, config, dynamic, watch

# --- Configuration ---
LOGLEVEL = os.environ.get('LOGLEVEL', 'INFO').upper()
logging.basicConfig(level=LOGLEVEL, format='%(asctime)s - %(levelname)s - %(message)s')

GRAFANA_URL = os.environ.get("GRAFANA_URL", "http://localhost:3000")
GRAFANA_USER = os.environ.get("GF_SECURITY_ADMIN_USER")
GRAFANA_PASSWORD = os.environ.get("GF_SECURITY_ADMIN_PASSWORD")
GRAFANA_ORG_MAPPING = os.environ.get("GRAFANA_ORG_MAPPING", "/data/org_mapping")
SIDECAR_PORT = int(os.environ.get("SIDECAR_PORT", 8080))
RECONCILE_INTERVAL_SECONDS = int(os.environ.get("RECONCILE_INTERVAL_SECONDS", 60))

# Grafana Custom Resource Definition details
GRAFANA_GROUP = "grafana.integreatly.org"
GRAFANA_VERSION = "v1beta1"
GRAFANA_PLURAL = "grafana"

# MTO Tenant Custom Resource Definition details
MTO_GROUP = "tenantoperator.stakater.com"
MTO_VERSION = "v1beta3"
MTO_PLURAL = "tenants"

# OpenShift Groups are also Custom Resources from Python's perspective
OPENSHIFT_GROUP_API = "user.openshift.io"
OPENSHIFT_GROUP_VERSION = "v1"
OPENSHIFT_GROUP_PLURAL = "groups"

# ConfigMap details for the dynamic org_mapping
MAPPING_CONFIGMAP_NAME = os.environ.get("CONFIGMAP_NAME", "grafana-oauth-mappings")
MAPPING_CONFIGMAP_NAMESPACE = os.environ.get("POD_NAMESPACE", "default")

# --- State Management for Readiness Probe ---
# An Event is a thread-safe flag.
INITIAL_SYNC_COMPLETE = threading.Event()

TENANTS = {}

lock = threading.Lock()


# --- Readiness Probe HTTP Server ---
class HealthCheckHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ready':
            if INITIAL_SYNC_COMPLETE.is_set():
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
            else:
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b'Initial sync not complete')
        else:
            self.send_response(404)
            self.end_headers()

def start_health_server():
    server = HTTPServer(('', SIDECAR_PORT), HealthCheckHandler)
    logging.info(f"Readiness probe server started on port {SIDECAR_PORT}")
    server.serve_forever()

def reconcile_grafana():
    k8s_custom_api = client.CustomObjectsApi()
    k8s_grafanas = k8s_custom_api.list_cluster_custom_object(GRAFANA_GROUP, GRAFANA_VERSION, GRAFANA_PLURAL)
    logging.info("(Reconcile) Starting reconciliation...")

    try:
        for grafana in k8s_grafanas.get("items", []):
            if grafana["metadata"]["namespace"] != POD_NAMESPACE:
                continue

            grafana['metadata']['labels']['sidecar-reconcile'] = f"{datetime.now().timestamp()}"
            api_response = k8s_custom_api.patch_namespaced_custom_object(GRAFANA_GROUP, GRAFANA_VERSION, POD_NAMESPACE, GRAFANA_PLURAL, grafana["metadata"]["name"], grafana)
    except Exception as e:
        logging.error(f"Error reconciling Grafana instances: {e}")

# --- K8S API Interaction ---
def get_all_tenants():
    k8s_custom_api = client.CustomObjectsApi()
    k8s_tenants = k8s_custom_api.list_cluster_custom_object(MTO_GROUP, MTO_VERSION, MTO_PLURAL)
    k8s_groups = k8s_custom_api.list_cluster_custom_object(OPENSHIFT_GROUP_API, OPENSHIFT_GROUP_VERSION, OPENSHIFT_GROUP_PLURAL)

    for tenant in k8s_tenants.get("items", []):
        if tenant["metadata"]["name"] in TENANTS:
            continue

        with lock:
            row = {
                "name": tenant["metadata"]["name"],
                "groups": [group["metadata"]["name"] for group in k8s_groups.get("items", []) if group["metadata"]["name"].startswith(tenant["metadata"]["name"])],
                "id": 0
            }
            TENANTS[row["name"]] = row

# --- Grafana API Interaction ---
def create_grafana_org(name):
    """Idempotently creates an organization in Grafana."""
    payload = {"name": name}
    url = f"{GRAFANA_URL}/api/orgs"
    try:
        check_response = requests.get(f"{url}/name/{name}", auth=(GRAFANA_USER, GRAFANA_PASSWORD))
        if check_response.status_code == 200:
            logging.info(f"Organization '{name}' already exists, no action needed.")
            resp = check_response.json()
            with lock:
                TENANTS[name]["id"] = resp.get("id", 0)
        elif check_response.status_code != 404:
            logging.error(f"Error creating org '{name}': {check_response.status_code} - {check_response.text}")
        else:
            response = requests.post(url, json=payload, auth=(GRAFANA_USER, GRAFANA_PASSWORD))
            if response.status_code == 200:
                logging.info(f"Successfully created organization '{name}'")
                resp = response.json()
                with lock:
                    TENANTS[name]["id"] = resp.get("id", 0)
            elif response.status_code == 409: # Conflict - means it already exists
                logging.info(f"Organization '{name}' already exists, no action needed.")
            else:
                logging.error(f"Error creating org '{name}': {response.status_code} - {response.text}")
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to connect to Grafana API: {e}")

def remove_grafana_org(name):
    url = f"{GRAFANA_URL}/api/orgs"
    try:
        response = requests.get(f"{url}/{TENANTS[name]['id']}", auth=(GRAFANA_USER, GRAFANA_PASSWORD))
        if response.status_code == 200:
            logging.info(f"Removed organization '{name}'")
            with lock:
                TENANTS[name] = None
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to connect to Grafana API: {e}")

# --- Initial Organization Mappings ---
def initial_org_mapping():
    logging.info("(Mapper) Checking for cached org_mapping...")
    k8s_core_api = client.CoreV1Api()
    cm = k8s_core_api.read_namespaced_config_map(MAPPING_CONFIGMAP_NAME, MAPPING_CONFIGMAP_NAMESPACE)
    current_content = cm.data.get("org_mapping", "")

    if current_content == "":
        logging.info(f"(Mapper) Cached org_mapping not found.")
    else:
        logging.info(f"(Mapper) Cached org_mapping found. Saving data to '{GRAFANA_ORG_MAPPING}' with: '{current_content}'")

    with open(GRAFANA_ORG_MAPPING, 'w') as f:
        f.write(current_content)

    return current_content

# --- Grafana Organisation Mappings ---
def org_mapping():
    mapping_entries = []
    for name, tenant in TENANTS.items():
        if (tenant["id"] > 0):
            name = tenant["id"]

        for group_name in tenant["groups"]:
            role = "None"
            if "admin" in group_name:
                if "cluster-admins" in group_name or "clusteradmins" in group_name:
                    role = "GrafanaAdmin"
                    group_name = "*"
                else:
                    role = "Admin"
            elif "owner" in group_name:
                role = "Editor"
            elif "edit" in group_name:
                role = "Editor"
            elif "view" in group_name:
                role = "Viewer"
            # Format: <ExternalGroupName>:<GrafanaOrgName>:Viewer
            mapping_entries.append(f"{group_name}:{name}:{role}")

    #mapping_entries.append("*:1:None")

    desired_mapping_str = " ".join(mapping_entries)

    existing_content = ""
    try:
        with open(GRAFANA_ORG_MAPPING, 'r') as f:
            existing_content = f.read()
    except FileNotFoundError:
        # File does not exist, so existing_content remains empty
        pass

    if existing_content == "" or (desired_mapping_str != "" and desired_mapping_str != existing_content):
        try:
            k8s_core_api = client.CoreV1Api()

            logging.info(f"(Mapper) org_mapping has changed. Saving data to '{GRAFANA_ORG_MAPPING}' with: '{desired_mapping_str}'")
            with open(GRAFANA_ORG_MAPPING, 'w') as f:
                f.write(desired_mapping_str)

            body = {"data": {"org_mapping": desired_mapping_str}}
            k8s_core_api.patch_namespaced_config_map(
                name=MAPPING_CONFIGMAP_NAME, namespace=MAPPING_CONFIGMAP_NAMESPACE, body=body
            )
            logging.info("(Mapper) ConfigMap patched successfully.")
        except client.ApiException as e:
            # Check for 404 on the ConfigMap specifically
            if e.status == 404 and "configmaps" in str(e.body):
                logging.error(f"(Mapper) CRITICAL: The ConfigMap '{MAPPING_CONFIGMAP_NAME}' was not found in namespace '{MAPPING_CONFIGMAP_NAMESPACE}'. Please create it.")
            else:
                logging.error(f"(Mapper) Kubernetes API error during reconciliation: {e}")
        except Exception as e:
            logging.error(f"(Mapper) An unexpected error occurred: {e}")

    return desired_mapping_str

# --- Task 1: Watch Tenants and Create Orgs ---
def watch_tenants_and_create_orgs():
    """
    Performs an initial sync of Tenant CRs to create orgs, signals readiness,
    and then watches for new Tenants to create their orgs immediately.
    """
    k8s_custom_api = client.CustomObjectsApi()
    
    logging.info("(Org Creator) Starting initial bulk sync of Tenant organizations...")
    try:
        for name, tenant in TENANTS.items():
            create_grafana_org(name)
    except client.ApiException as e:
        logging.error(f"(Org Creator) Error fetching initial tenant list: {e}")
        # In a real scenario, might want to exit if this fails
    
    logging.info("(Org Creator) Initial bulk sync complete. Signaling readiness.")
    INITIAL_SYNC_COMPLETE.set()

    logging.info("(Org Creator) Starting to watch for Tenant changes...")
    w = watch.Watch()
    stream = w.stream(k8s_custom_api.list_cluster_custom_object, MTO_GROUP, MTO_VERSION, MTO_PLURAL)
    for event in stream:
        tenant_name = event['object']['metadata']['name']
        logging.info(f"(Org Creator) Detected changes on Tenant '{tenant_name}': {event['type']}.")
        if event['type'] in ["ADDED","MODIFIED"]:
            if tenant_name in TENANTS:
                continue

            logging.info(f"(Org Creator) Detected new Tenant '{tenant_name}', creating org.")
            create_grafana_org(tenant_name)
        elif event['type'] == "DELETED":
            remove_grafana_org(tenant_name)
            #INITIAL_SYNC_COMPLETE.clear()

# --- Task 2: Periodically Reconcile the Org Mapping ConfigMap ---
def reconcile_org_mapping_periodically():
    """
    Periodically scans all MTO-related OpenShift Groups and updates a ConfigMap
    with the correct `org_mapping` string for Grafana.
    """

    ## Wait until the initial org sync is done before starting the reconciliation
    #INITIAL_SYNC_COMPLETE.wait()
    #logging.info("(Mapper) Initial sync is complete, starting reconciliation loop.")

    k8s_core_api = client.CoreV1Api()
    while True:
        try:
            logging.info("(Mapper) Starting periodic reconciliation of org mappings...")

            desired_mapping_str = org_mapping()

            # 3. Get the current mapping from the ConfigMap
            cm = k8s_core_api.read_namespaced_config_map(MAPPING_CONFIGMAP_NAME, MAPPING_CONFIGMAP_NAMESPACE)
            current_mapping_str = cm.data.get("org_mapping", "")

            # 4. If they differ, patch the ConfigMap
            if desired_mapping_str != current_mapping_str:
                logging.info(f"(Mapper) org_mapping has changed. Patching ConfigMap with: '{desired_mapping_str}'")

                body = {"data": {"org_mapping": desired_mapping_str}}
                k8s_core_api.patch_namespaced_config_map(
                    name=MAPPING_CONFIGMAP_NAME, namespace=MAPPING_CONFIGMAP_NAMESPACE, body=body
                )
                logging.info("(Mapper) ConfigMap patched successfully.")
                reconcile_grafana()
            else:
                logging.info("(Mapper) No changes to org_mapping needed.")

        except client.ApiException as e:
            # Check for 404 on the ConfigMap specifically
            if e.status == 404 and "configmaps" in str(e.body):
                    logging.error(f"(Mapper) CRITICAL: The ConfigMap '{MAPPING_CONFIGMAP_NAME}' was not found in namespace '{MAPPING_CONFIGMAP_NAMESPACE}'. Please create it.")
            else:
                logging.error(f"(Mapper) Kubernetes API error during reconciliation: {e}")
        except Exception as e:
            logging.error(f"(Mapper) An unexpected error occurred: {e}")

        time.sleep(RECONCILE_INTERVAL_SECONDS)

# --- Main Orchestrator ---
def main():
    if not GRAFANA_USER:
        logging.error("GRAFANA_USER environment variable not set. Exiting.")
        return
    if not GRAFANA_PASSWORD:
        logging.error("GRAFANA_PASSWORD environment variable not set. Exiting.")
        return

    logging.info("Load the incluster config.")
    config.load_incluster_config()

    initial_org_mapping()

    get_all_tenants()

    logging.info("Waiting for Grafana API to become available...")
    while True:
        try:
            requests.get(f"{GRAFANA_URL}/api/health", timeout=2)
            logging.info("Grafana API is ready.")
            break
        except requests.exceptions.RequestException:
            time.sleep(2)
    
    # --- Start All Background Tasks ---
    
    # 1. Start the readiness probe server
    logging.info("Start the readiness probe server.")
    health_thread = threading.Thread(target=start_health_server, daemon=True)
    health_thread.start()

    # 2. Start the tenant watcher and org creator
    logging.info("Start the tenant watcher and org creator")
    org_creator_thread = threading.Thread(target=watch_tenants_and_create_orgs, daemon=True)
    org_creator_thread.start()

    # 3. Start the periodic org mapping reconciler
    logging.info("Start the periodic org mapping reconciler")
    mapping_reconciler_thread = threading.Thread(target=reconcile_org_mapping_periodically, daemon=True)
    mapping_reconciler_thread.start()

    # --- Keep the Main Thread Alive ---
    logging.info("Sidecar started with all tasks running.")
    while True:
        time.sleep(3600) # Sleep indefinitely while daemon threads run

if __name__ == "__main__":
    main()