# Vgurukool Platform - Issues, Diagnostics, and Fixes

This document serves as the central log of technical issues, root causes, remediation steps, and verification procedures across the **Vgurukool (CNOE AWS Reference Implementation)** platform on Amazon EKS.

---

## Table of Contents

1. [Backstage Catalog: No Apps Listed / Catalog Ingestion Crash](#1-backstage-catalog-no-apps-listed--catalog-ingestion-crash)
2. [CAIPE: Dynamic Agents Runtime 503 Service Unavailable](#2-caipe-dynamic-agents-runtime-503-service-unavailable)
3. [CAIPE: Workflows Engine Feature Disabled](#3-caipe-workflows-engine-feature-disabled)
4. [CAIPE: Empty Models Selector & OpenFGA ReBAC Access](#4-caipe-empty-models-selector--openfga-rebac-access)
5. [CAIPE: MongoDB Persistence Not Configured](#5-caipe-mongodb-persistence-not-configured)
6. [CAIPE: Platform Health Probes Degraded / Down](#6-caipe-platform-health-probes-degraded--down)
7. [Keycloak: Premature Session Expiration Warning (1-Minute Expiry)](#7-keycloak-premature-session-expiration-warning-1-minute-expiry)
8. [LiteLLM: Dedicated Namespace Migration & Pod Balancing](#8-litellm-dedicated-namespace-migration--pod-balancing)

---

## 1. Backstage Catalog: No Apps Listed / Catalog Ingestion Crash

### Symptoms
* Navigating to Backstage (`https://vgurukool.com`) showed:
  * **"No records found"** under Components.
  * No platform applications or systems listed in the software catalog.

### Root Causes
1. **Catalog Refresh Crash (RS256 JWT Signing Error):**
   * In `idp-aws/packages/backstage/values.yaml` and ConfigMap `backstage-app-config`, `integrations.github` included:
     ```yaml
     integrations:
       github:
         - host: github.com
           apps:
             - $include: /app/config/github-integration.yaml
     ```
   * The mounted secret `integrations` contained dummy placeholder credentials (`appId: 1234`, `privateKey: -----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----`).
   * When Backstage attempted to ingest catalog files from `github.com`, the GitHub App credentials provider tried to parse the dummy RSA private key, throwing:
     ```
     Unable to read url, Error: secretOrPrivateKey must be an asymmetric key when using RS256
     ```
   * This exception crashed all catalog refresh tasks, preventing any files from being fetched.
2. **Missing Component Manifests:**
   * `idp-aws/templates/backstage/catalog-info.yaml` only referenced templates (`basic`, `argo-workflows`, `app-with-bucket`, `ray-serve`) and guests organization data. There were zero `kind: Component` files defined for the cluster services.
3. **Catalog Kind Allow-list Restrictions:**
   * `catalog.rules.allow` did not permit `User`, `Group`, or `Domain`, causing organization entities to be rejected with `NotAllowedError`.

### Remediation & Fixes
1. **Removed Broken GitHub App Configuration:**
   * Updated `packages/backstage/values.yaml`:
     ```yaml
     integrations:
       github:
         - host: github.com
     ```
   * Backstage now reads public GitHub repositories unauthenticated without failing RS256 JWT signing.
2. **Expanded Allowed Rules:**
   * Added `User`, `Group`, and `Domain` to `catalog.rules.allow` and `catalog.locations[].rules.allow`.
3. **Created Platform Components Manifest (`templates/backstage/all-components.yaml`):**
   * Declared **3 Systems**:
     * `lakshmi-suite` (Lakshmi Business Suite)
     * `ai-platform` (AI & Multi-Agent Platform)
     * `core-infrastructure` (Core Cloud & IDP Infrastructure)
   * Declared **13 Components**:
     * **Lakshmi Apps:** `ashta-lakshmi`, `dhana-lakshmi`, `dhanya-lakshmi`, `gaja-lakshmi`, `vidya-lakshmi`
     * **AI Platform:** `caipe`, `learnhouse`, `maic-ui`, `litellm`
     * **Core Tools:** `argocd`, `argo-workflows`, `keycloak`, `backstage`
   * Attached annotations (`backstage.io/view-url`, `argocd/app-name`, `backstage.io/kubernetes-label-selector`) and direct web links.
4. **Registered Ownership and Locations:**
   * Updated `templates/backstage/catalog-info.yaml` with `./all-components.yaml`.
   * Updated `templates/backstage/organization/guests.yaml` to include users `guest`, `user1`, `user2`, `admin` as members of group `guests`. All components specify `owner: guests` so they appear under both "My Components" and "All".
5. **GitOps Rollout:**
   * Committed and pushed to `main` branch of `vgurukool/idp-aws.git` (`bd65a67`, `c4b91d2`, `b29bdb3`).
   * Synced `ConfigMap/backstage-app-config` via Argo CD and restarted deployment `backstage`.

### Verification
* Queried PostgreSQL database `backstage_plugin_catalog`:
  ```sql
  SELECT entity_ref, errors FROM refresh_state;
  ```
  **Result:** 29 entities (13 components, 3 systems, 4 templates, 4 users, 1 group, 4 locations) all report `errors: []` (zero errors).
* Navigated to `https://vgurukool.com`: All 13 applications are listed, categorized by system, and clickable.

---

## 2. CAIPE: Dynamic Agents Runtime 503 Service Unavailable

### Symptoms
* In CAIPE UI, sending a chat message to agent `Hello World` failed with:
  ```json
  Error: HTTP error: 503 . {"success":false,"error":"Dynamic agents service is not available. Please ensure it is running."}
  ```

### Root Causes
* CAIPE BFF routes SSE agent chat streams to `DYNAMIC_AGENTS_URL/api/v1/chat/stream/start`.
* The `dynamic-agents` backend container (`ghcr.io/cnoe-io/caipe-dynamic-agents:0.5.66`) was not deployed in the Kubernetes cluster.

### Remediation & Fixes
1. Created `caipe/chart/templates/dynamic-agents.yaml` deploying the `dynamic-agents` runtime on ports 8001 (HTTP) and 8100 (A2A).
2. Connected `dynamic-agents` to:
   * **MongoDB:** `caipe-mongodb.caipe.svc.cluster.local:27017`
   * **LiteLLM:** `http://litellm.litellm.svc.cluster.local:4000/v1` (with `LITELLM_MASTER_KEY`)
   * **Keycloak:** `https://vgurukool.com/keycloak/realms/cnoe`
   * **OpenFGA:** `http://openfga:8080`
3. Set `DYNAMIC_AGENTS_URL: "http://dynamic-agents:8001"` and `DYNAMIC_AGENTS_ENABLED: "true"` in `caipe/chart/values.yaml`.
4. Pushed commit `df89a6160` to `vgurukool/caipe.git` and synced via Argo CD.

### Verification
* Pod `dynamic-agents-697565bdc6-4z6qf` is `1/1 Running`.
* Live SSE chat test to `hello-world` agent:
  ```bash
  curl -s -N -X POST "http://caipe:3000/api/dynamic-agents/hello-world/chat" \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"Hello world!"}]}'
  ```
  **Result:** HTTP 200 with full streaming tokens returned: `"Hello! I am Hello World, a friendly default assistant..."`.

---

## 3. CAIPE: Workflows Engine Feature Disabled

### Symptoms
* Navigating to `https://caipe.vgurukool.com/workflows` showed:
  ```
  Workflows not enabled: The Workflows feature is not enabled on this instance. Set WORKFLOWS_ENABLED=true to activate it.
  ```

### Root Causes
* Feature flags `WORKFLOWS_ENABLED`, `NEXT_PUBLIC_WORKFLOWS_ENABLED`, and `WORKFLOW_RUNNER_ENABLED` defaulted to `false`.

### Remediation & Fixes
* Added environment flags to `caipe/chart/values.yaml`:
  ```yaml
  env:
    WORKFLOWS_ENABLED: "true"
    NEXT_PUBLIC_WORKFLOWS_ENABLED: "true"
    WORKFLOW_RUNNER_ENABLED: "true"
  ```
* Pushed commits `d103ed89f` and `a7c459bf7` to `vgurukool/caipe.git` and synced Argo CD.

### Verification
* `GET /workflows` loads HTTP 200 with the visual `WorkflowCanvas`, drag-and-drop step editor, and execution history.
* CRUD API `/api/workflow-configs` handles workflow lifecycle operations cleanly.

---

## 4. CAIPE: Empty Models Selector & OpenFGA ReBAC Access

### Symptoms
* Navigating to dynamic agent configuration in CAIPE showed an empty Model selection dropdown.

### Root Causes
1. CAIPE dynamic agents discover models by querying MongoDB collection `llm_models` at `/api/dynamic-agents/models`. By default, no models were seeded into the database.
2. Model query results are filtered by OpenFGA ReBAC checks (`filterResourcesByPermission(..., { type: "llm_model", action: "read" })`). Because OpenFGA was not deployed, ReBAC checks failed closed.

### Remediation & Fixes
1. **Model Catalog Seeding:**
   * Created `caipe/chart/templates/app-configmap.yaml` defining 5 models (`gemini-2.5-flash`, `gpt-4o`, `gemini-1.5-flash`, `gemini-1.5-pro`, `gpt-3.5-turbo`).
   * Mounted config into CAIPE pods; on boot `[seed-config]` automatically populates `llm_models`.
2. **OpenFGA Authorization Service:**
   * Created `caipe/chart/templates/openfga.yaml` running `openfga/openfga:v1.15.1`.
   * Added `openfga-init` sidecar script (`seed.py`) to create store `caipe-openfga`, upload authorization model, and write wildcard reader tuples (`user:*` -> `reader` -> `llm_model:*`).
3. **Keycloak Audience Alignment:**
   * Added `oidc-audience-mapper` (`caipe-audience`) to Keycloak client `caipe` in realm `cnoe`.
   * Set `OIDC_ACCEPTED_AUDIENCES: "caipe,account"` in CAIPE values.

### Verification
* Querying `/api/dynamic-agents/models` with an authenticated token returns all 5 models successfully.
* UI Model dropdown displays all 5 LiteLLM-backed models.

---

## 5. CAIPE: MongoDB Persistence Not Configured

### Symptoms
* Navigating CAIPE surfaces displayed:
  ```
  MongoDB is not configured. Set MONGODB_URI and MONGODB_DATABASE environment variables.
  ```

### Root Causes
* CAIPE operated in degraded `localStorage` mode because no MongoDB instance was provisioned.

### Remediation & Fixes
1. Created `caipe/chart/templates/mongodb.yaml` deploying a `mongo:7.0` StatefulSet on a 5Gi AWS EBS `gp3` PVC.
2. Injected credentials securely via Kubernetes Secret `caipe-secret`:
   * `MONGODB_URI: mongodb://caipe:<password>@caipe-mongodb.caipe.svc.cluster.local:27017/caipe?authSource=admin`
3. Pushed commit `37ff9a186` to `vgurukool/caipe.git` and synced Argo CD.

### Verification
* StatefulSet `caipe-mongodb-0` is `1/1 Running` with bound PVC.
* CAIPE pods log: `✅ Connected to MongoDB database: caipe`.
* Diagnostic probe `/api/platform/health?diagnostics=1` returns `caipe-mongodb: healthy`.

---

## 6. CAIPE: Platform Health Probes Degraded / Down

### Symptoms
* Status page (`https://caipe.vgurukool.com/admin?cat=platform&tab=health`) showed:
  * **Chat Runtime:** `Down` (unreachable)
  * **Knowledge Bases:** `Degraded` (HTTP 502)
  * **Audit Service:** `Degraded` (fetch failed)

### Root Causes
* Probes queried non-existent external microservices (`rag-server`, `audit-service`, `caipe-supervisor`).

### Remediation & Fixes
* Configured `caipe/chart/values.yaml`:
  * `A2A_BASE_URL: "http://localhost:3000/api"` (probes `/api/health`, returns HTTP 200).
  * `RAG_ENABLED: "false"` (gracefully marks Knowledge Bases disabled).
  * `AUDIT_LOG_BACKEND: "disabled"` (gracefully marks Audit Service disabled).
  * `KEYCLOAK_URL` and `KEYCLOAK_POSTGRES_HOST` pointed to in-cluster services.
* Pushed commits `5c10918e5` and `1042bec7c` to `vgurukool/caipe.git`.

### Verification
* Health API `/api/platform/health` returns:
  * **Overall Status:** `healthy`
  * **Chat Runtime:** `healthy`
  * **Authentication:** `healthy`
  * **Knowledge Bases / Audit Service:** `disabled`

---

## 7. Keycloak: Premature Session Expiration Warning (1-Minute Expiry)

### Symptoms
* Upon signing into CAIPE or other platform apps, the UI immediately popped up:
  ```
  Session Expiring Soon: Your session will expire in 1 minute. Attempting to refresh automatically.
  ```

### Root Causes
* In Keycloak realm `cnoe`, `accessTokenLifespan` was set to `60` seconds.
* CAIPE UI calculates warning threshold at `expiresAt - 300s` (5 minutes). Since `60s < 300s`, any fresh token was immediately within the warning window.

### Remediation & Fixes
* Updated realm `cnoe` via Keycloak admin CLI (`kcadm.sh`):
  * `accessTokenLifespan`: increased from `60` to `3600` seconds (1 hour).
  * `ssoSessionIdleTimeout`: increased from `1800` to `28800` seconds (8 hours).
  * `ssoSessionMaxLifespan`: preserved at `36000` seconds (10 hours).

### Verification
* Token endpoint issues access tokens with `expires_in: 3600` and refresh tokens with `refresh_expires_in: 28800`.
* The premature 1-minute expiration popup is completely eliminated.

---

## 8. LiteLLM: Dedicated Namespace Migration & Pod Balancing

### Symptoms
* LiteLLM originally ran in shared namespace `vgurukool`, creating configuration coupling with business applications.
* During cluster scale-up, EBS volume node pinning caused `learnhouse-db-0` to enter `Pending` state when a node reached its 35-pod capacity.

### Remediation & Fixes
1. Created dedicated namespace `litellm`.
2. Backed up PostgreSQL database from `vgurukool` and restored into `litellm-db-0` in `litellm` namespace.
3. Deployed `litellm` deployment, service, ingress, and Let's Encrypt TLS certificate in `litellm` namespace.
4. Updated dependent applications (`caipe`, `learnhouse`, `maic-ui`) to target `http://litellm.litellm.svc.cluster.local:4000/v1`.
5. Cleaned up legacy LiteLLM resources from `vgurukool` namespace.
6. Rebalanced duplicate stateless pods across nodes in `us-east-2a` and `us-east-2c`, unblocking EBS-pinned volumes.

### Verification
* `https://litellm.vgurukool.com/health/liveliness` returns `"I'm alive!"`.
* `https://litellm.vgurukool.com/.well-known/litellm-ui-config` reports `sso_configured: true`.
* Internal connectivity verified from CAIPE, LearnHouse, and MAIC containers.
