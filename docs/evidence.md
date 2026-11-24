<!--
=============================================================================
File        : docs/evidence.md
Assignment  : DSO202 Assignment 4
Purpose     : Command output for every task, one section per task, in the
              order the tasks were performed. Each item shows the command that
              was run and its output. Credential values and the sealing key
              never appear here; only key names, sizes and search results do.
=============================================================================
-->
# DSO202 Assignment 4: Evidence

Cluster: kind `dso202-gitops` (single node, `kindest/node:v1.36.1`).
Repository: `https://github.com/Kinley-pal8/dso202-gitops.git`.
Times are local (UTC+6). Kubernetes timestamps are UTC.

Screenshots are stored in `docs/screenshots/` and referenced where the brief asks for them.

---

## Task 1: Repository, Chart Contract and Cluster

### Tool check (section 3.2) and Sealed Secrets chart availability

```text
$ docker version --format '{{.Server.Version}}'
29.9.1

$ kind version
kind v0.32.0 go1.26.3 linux/amd64

$ kubectl version --client
Client Version: v1.36.3
Kustomize Version: v5.8.1

$ helm version --short
v4.3.1+gc0d08d0

$ git --version
git version 2.53.0

$ argocd version --client
argocd: v3.5.6+c2b1e30
  BuildDate: 2026-10-20T19:01:52Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
  GitTreeState: clean
  GoVersion: go1.26.10
  Compiler: gc
  Platform: linux/amd64

$ kubeseal --version
kubeseal version: 0.40.0

$ helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets
"sealed-secrets" has been added to your repositories

$ helm repo update sealed-secrets
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "sealed-secrets" chart repository
Update Complete. ⎈Happy Helming!⎈

$ helm search repo sealed-secrets/sealed-secrets --versions | head -5
NAME                         	CHART VERSION	APP VERSION	DESCRIPTION                                  
sealed-secrets/sealed-secrets	2.22.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.21.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.20.0       	0.40.0     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.19.3       	0.39.1     	Helm chart for the sealed-secrets controller.
```

Chart `2.20.0` (controller `0.40.0`) is listed, so the pinned version is available.

### `.gitignore` is the first commit
```text
$ git log --reverse --oneline | head -1
246b660 Add .gitignore before any other file (Listing 1)
```

### Chart contract

| # | Requirement | Where it is satisfied |
|---|---|---|
| C1 | Image repository and tag are values for each tier | `values.yaml`: `database.image`, `backend.image`, `frontend.image` (`repository`, `tag`). Templates use only `.Values.<tier>.image.*`. `values.schema.json` rejects `latest`, `stable`, `master` and `HEAD`. |
| C2 | Per-tier configuration rendered from values | `values.yaml`: `database.config`, `backend.config`, `frontend.config`, rendered into `db-config`, `backend-config` and `frontend-config` by `templates/configmaps.yaml` and loaded with `envFrom`. A new variable is a values change only. |
| C3 | No `Secret` rendered; credentials from `existingSecret` | `values.yaml`: `existingSecret` (required by the `tasktracker.secretName` helper). Both environment files set it to `tasktracker-credentials`. `secretKeyRef` is used in `database.yaml` and `backend.yaml`. |
| C4 | Readiness probes on all three tiers | `database.yaml` (`pg_isready`), `backend.yaml` (`GET /api/status`), `frontend.yaml` (`GET /`) |
| C5 | Sync waves db `"0"`, backend `"1"`, frontend `"2"` | `_helpers.tpl` `tasktracker.wave`, used on every object of each tier |
| C6 | `progressDeadlineSeconds: 120` on backend and frontend | `values.yaml`: `progressDeadlineSeconds`, used in `backend.yaml` and `frontend.yaml` |
| C7 | Requests and limits on every container | `values.yaml`: `<tier>.resources` (the schema requires both). The smoke-test Job states its own. |
| C8 | No Namespace, ResourceQuota, LimitRange, Role or RoleBinding | Removed from the Assignment 3 chart (`governance.yaml`, `rbac.yaml`, `operator.yaml`, `crds/`). They now live in `platform/<env>/`. |
| C9 | Ingress template disabled by default | `templates/ingress.yaml` is wrapped in `if .Values.ingress.enabled`, and `ingress.enabled: false` |
| C10 | Frontend Service is NodePort, port is a value | `frontend.yaml` `type: NodePort`, `nodePort` from `frontend.service.nodePort` (30080 in `environments/dev`, 30081 in `environments/staging`) |
| C11 | `helm lint` clean, `helm template` succeeds for both | Output below |

### helm lint and the kinds the chart renders

```text
$ helm lint charts/tasktracker -f environments/dev/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm lint charts/tasktracker -f environments/staging/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep -E '^kind:' | sort | uniq -c
      3 kind: ConfigMap
      2 kind: Deployment
      3 kind: Service
      1 kind: ServiceAccount
      1 kind: StatefulSet

$ helm template tasktracker charts/tasktracker -f environments/staging/values.yaml | grep -E '^kind:' | sort | uniq -c
      3 kind: ConfigMap
      2 kind: Deployment
      3 kind: Service
      1 kind: ServiceAccount
      1 kind: StatefulSet
```

The chart renders `ConfigMap`, `Deployment`, `Service`, `ServiceAccount` and `StatefulSet`. The `Job` hook (Listing 13) was added in Task 5. The full list including it is shown in Task 3.

### Cluster

```text
$ kind get clusters
dso202

$ kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml
Creating cluster "dso202-gitops" ...
 • Ensuring node image (kindest/node:v1.36.1) 🖼  ...
 ✓ Ensuring node image (kindest/node:v1.36.1) 🖼
 • Preparing nodes 📦   ...
 ✓ Preparing nodes 📦 
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing CNI 🔌  ...
 ✓ Installing CNI 🔌
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-dso202-gitops"
You can now use your cluster with:

kubectl cluster-info --context kind-dso202-gitops

Thanks for using kind! 😊

$ kubectl config current-context
kind-dso202-gitops

$ kubectl get nodes -o wide
NAME                          STATUS     ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION             CONTAINER-RUNTIME
dso202-gitops-control-plane   NotReady   control-plane   5s    v1.36.1   172.18.0.4    <none>        Debian GNU/Linux 13 (trixie)   7.1.5+kali-amd64 (amd64)   containerd://2.3.1

$ docker ps --filter name=dso202-gitops --format '{{.Names}}   {{.Ports}}'
dso202-gitops-control-plane   0.0.0.0:30080->30080/tcp, 127.0.0.1:37943->6443/tcp
```

`kind get clusters` lists `dso202`, the cluster from Assignments 1 and 2. It has no host port mappings, so it does not hold port 30080 and was left running. The `docker ps` line shows host port 30080 mapped to the new node.

---

## Task 2: Install Argo CD Declaratively

```text
$ kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$'
kind: Deployment
kind: Deployment
kind: Deployment
kind: Deployment
kind: Deployment
kind: Deployment
kind: StatefulSet

$ kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u
        image: ghcr.io/dexidp/dex:v2.45.1
        image: public.ecr.aws/docker/library/redis:8.2.3-alpine
        image: quay.io/argoproj/argocd:v3.5.6

$ kubectl apply -k bootstrap/argocd --server-side --force-conflicts | tail -15
service/argocd-server-metrics serverside-applied
deployment.apps/argocd-applicationset-controller serverside-applied
deployment.apps/argocd-dex-server serverside-applied
deployment.apps/argocd-notifications-controller serverside-applied
deployment.apps/argocd-redis serverside-applied
deployment.apps/argocd-repo-server serverside-applied
deployment.apps/argocd-server serverside-applied
statefulset.apps/argocd-application-controller serverside-applied
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-redis-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-server-network-policy serverside-applied

$ kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
deployment.apps/argocd-applicationset-controller condition met
timed out waiting for the condition on deployments/argocd-dex-server
timed out waiting for the condition on deployments/argocd-notifications-controller
timed out waiting for the condition on deployments/argocd-redis
timed out waiting for the condition on deployments/argocd-repo-server
timed out waiting for the condition on deployments/argocd-server

$ kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
partitioned roll out complete: 1 new pods have been updated...

$ kubectl get pods -n argocd
NAME                                                READY   STATUS            RESTARTS   AGE
argocd-application-controller-0                     1/1     Running           0          5m1s
argocd-applicationset-controller-58bb5c7479-cwbxx   1/1     Running           0          5m1s
argocd-dex-server-dd6b85d9c-mbqx7                   0/1     PodInitializing   0          5m1s
argocd-notifications-controller-6b85c65458-b6vq9    1/1     Running           0          5m1s
argocd-redis-869b85489d-spsb4                       0/1     PodInitializing   0          5m1s
argocd-repo-server-5bf66565cd-fcjsn                 0/1     PodInitializing   0          5m1s
argocd-server-7474bb8f76-5bxmr                      0/1     Running           0          5m1s

$ kubectl get crd | grep argoproj.io
applications.argoproj.io      2026-11-24T18:53:42Z
applicationsets.argoproj.io   2026-11-24T18:53:42Z
appprojects.argoproj.io       2026-11-24T18:53:42Z

$ kubectl get configmap argocd-cm -n argocd -o yaml | grep -E 'timeout.reconciliation|accounts.reviewer|resource.customizations.health.argoproj.io_Application'
  accounts.reviewer: login
  resource.customizations.health.argoproj.io_Application: |
  timeout.reconciliation: 60s
  timeout.reconciliation.jitter: 10s

$ kubectl get pods -n argocd   (after the slow dex image pull finished)
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          15m
argocd-applicationset-controller-58bb5c7479-cwbxx   1/1     Running   0          15m
argocd-dex-server-dd6b85d9c-mbqx7                   1/1     Running   0          15m
argocd-notifications-controller-6b85c65458-b6vq9    1/1     Running   0          15m
argocd-redis-869b85489d-spsb4                       1/1     Running   0          15m
argocd-repo-server-5bf66565cd-fcjsn                 1/1     Running   0          15m
argocd-server-7474bb8f76-5bxmr                      1/1     Running   0          15m

$ argocd version --client --short
argocd: v3.5.6+c2b1e30
$ argocd version
argocd: v3.5.6+c2b1e30
  BuildDate: 2026-10-20T19:01:52Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
  GitTreeState: clean
  GoVersion: go1.26.10
  Compiler: gc
  Platform: linux/amd64
argocd-server: v3.5.6
  BuildDate: 2026-10-20T18:33:20Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
  GitTreeState: clean
  GitTag: v3.5.6
  GoVersion: go1.26.10
  Compiler: gc
  Platform: linux/amd64
  Kustomize Version: v5.8.1 2026-02-09T16:15:27Z
  Helm Version: v4.2.1+gd591a19
  Kubectl Version: v0.36.1
  Jsonnet Version: v0.22.0
```

The first `kubectl wait` timed out only because the images were still downloading on a slow connection. The second `kubectl get pods` shows all seven Pods `Running`, with three CRDs present.

Screenshot: `docs/screenshots/task2-argocd-ui.png` (Argo CD UI after sign-in as `admin`).

---

## Task 3: AppProjects and the Root Application

### Whitelist versus the kinds the chart renders

```text
$ helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep -E '^kind:' | sort -u
kind: ConfigMap
kind: Deployment
kind: Job
kind: Service
kind: ServiceAccount
kind: StatefulSet
```

These are exactly the six kinds in `argocd/projects/dso202.yaml`: Deployment, StatefulSet, Service, ConfigMap, ServiceAccount and Job. No addition was needed. The PersistentVolumeClaim comes from the StatefulSet's `volumeClaimTemplates` and is created by the StatefulSet controller, not by Argo CD, so it does not need whitelisting.

### Bootstrap and result

```text
$ kubectl apply -f bootstrap/root
appproject.argoproj.io/platform created
Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name including a path (/) to avoid accidental conflicts with other finalizer writers
application.argoproj.io/root created
```

```text
$ kubectl get appproject,application -n argocd
NAME                              AGE
appproject.argoproj.io/default    21m
appproject.argoproj.io/dso202     51s
appproject.argoproj.io/platform   55s

NAME                           SYNC STATUS   HEALTH STATUS
application.argoproj.io/root   Synced        Healthy

$ argocd app get root
Name:               argocd/root
Project:            platform
Server:             https://kubernetes.default.svc
Namespace:          argocd
URL:                https://localhost:8080/applications/root
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           main
  Path:             argocd
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (965a87b)
Health Status:      Healthy

GROUP        KIND        NAMESPACE  NAME    STATUS  HEALTH  HOOK  MESSAGE
argoproj.io  AppProject  argocd     dso202  Synced                appproject.argoproj.io/dso202 unchanged

$ argocd proj get dso202
Name:                        dso202
Description:                 Task Tracker workloads for the dev and staging environments
Destinations:                https://kubernetes.default.svc,dso202-dev
                             https://kubernetes.default.svc,dso202-staging
Repositories:                https://github.com/Kinley-pal8/dso202-gitops.git
Source Namespaces:           <none>
Scoped Repositories:         <none>
Allowed Cluster Resources:   <none>
Scoped Clusters:             <none>
Denied Namespaced Resources: <none>
Signature keys:              <none>
Orphaned Resources:          disabled
```

`dso202` appears in the resource list of `argocd app get root`, so the root created it. Only `platform` and `root` were applied by hand.

Screenshot: `docs/screenshots/task3-root-tree.png` (resource tree of the root Application).

---

## Task 4: Platform Layer and Sealed Secrets

### Step 1: controller installed from Git, and step 2: sealing-key backup

The Application status was polled every 10 s after the push (`<n> <sync>/<health>`). The Application was `Synced` while the controller Pod was still starting, which is the example used in Q3:

```text
1
2 Synced/Progressing
3 Synced/Progressing
4 Synced/Progressing
5 Synced/Progressing
6 Synced/Progressing
7 Synced/Healthy
```

```text
$ kubectl get applications -n argocd
NAME             SYNC STATUS   HEALTH STATUS
root             Synced        Healthy
sealed-secrets   Synced        Healthy

$ kubectl get pods -n sealed-secrets
NAME                                        READY   STATUS    RESTARTS   AGE
sealed-secrets-controller-8b5ffdf69-46jlw   1/1     Running   0          53s

$ kubectl get crd sealedsecrets.bitnami.com
NAME                        CREATED AT
sealedsecrets.bitnami.com   2026-11-24T19:20:16Z

$ kubectl get deploy -n sealed-secrets -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
docker.io/bitnami/sealed-secrets-controller:0.40.0
$ kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ../dso202-keys/sealing-key.backup.yaml
$ chmod 600 ../dso202-keys/sealing-key.backup.yaml
$ ls -l ../dso202-keys/
total 8
-rw------- 1 kp kp 7087 Nov 25 01:21 sealing-key.backup.yaml
```

The backup file has mode `600`. It is stored in `../dso202-keys/`, outside the repository, and its contents were never displayed.

### Step 6: platform Applications, namespaces, Secrets, quota, limits and RBAC

```text
$ kubectl get applications -n argocd
NAME               SYNC STATUS   HEALTH STATUS
platform-dev       Synced        Healthy
platform-staging   Synced        Healthy
root               Synced        Healthy
sealed-secrets     Synced        Healthy

$ kubectl get namespaces | grep dso202
dso202-dev           Active   10s
dso202-staging       Active   11s

$ kubectl get sealedsecret -n dso202-dev
NAME                      STATUS   SYNCED   AGE
tasktracker-credentials            True     9s

$ kubectl get sealedsecret -n dso202-staging
NAME                      STATUS   SYNCED   AGE
tasktracker-credentials            True     10s

$ kubectl describe secret tasktracker-credentials -n dso202-dev
Name:         tasktracker-credentials
Namespace:    dso202-dev
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
DB_PASSWORD:        32 bytes
DB_USER:            15 bytes
POSTGRES_PASSWORD:  32 bytes
POSTGRES_USER:      15 bytes

$ kubectl describe secret tasktracker-credentials -n dso202-staging
Name:         tasktracker-credentials
Namespace:    dso202-staging
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
DB_PASSWORD:        32 bytes
DB_USER:            19 bytes
POSTGRES_PASSWORD:  32 bytes
POSTGRES_USER:      19 bytes

$ kubectl get resourcequota,limitrange -n dso202-dev
NAME                               REQUEST                                                                              LIMIT                                   AGE
resourcequota/task-tracker-quota   persistentvolumeclaims: 0/2, pods: 0/20, requests.cpu: 0/1, requests.memory: 0/1Gi   limits.cpu: 0/3, limits.memory: 0/2Gi   10s

NAME                             CREATED AT
limitrange/task-tracker-limits   2026-11-24T19:21:53Z

$ kubectl get resourcequota,limitrange -n dso202-staging
NAME                               REQUEST                                                                              LIMIT                                   AGE
resourcequota/task-tracker-quota   persistentvolumeclaims: 0/2, pods: 0/20, requests.cpu: 0/1, requests.memory: 0/1Gi   limits.cpu: 0/3, limits.memory: 0/2Gi   11s

NAME                             CREATED AT
limitrange/task-tracker-limits   2026-11-24T19:21:52Z

$ kubectl get serviceaccount/viewer role/namespace-readonly rolebinding/viewer-namespace-readonly -n dso202-dev
NAME                    AGE
serviceaccount/viewer   10m

NAME                                                CREATED AT
role.rbac.authorization.k8s.io/namespace-readonly   2026-11-24T19:21:53Z

NAME                                                              ROLE                      AGE
rolebinding.rbac.authorization.k8s.io/viewer-namespace-readonly   Role/namespace-readonly   10m
```

Both Secrets were created by the Sealed Secrets controller with the four keys. The staging values are different, which is visible in the key sizes. Only sizes are shown, never values.

### Step 7: no plaintext in Git

```text
# Step 7: history search, one search per distinct credential value. Values are never printed;
# each line shows the key tested and the number of output lines of: git log -p --all -S'<value>' | head
$ git log -p --all -S'<dev DB_USER value>' | head     -> 0 lines of output
$ git log -p --all -S'<dev DB_PASSWORD value>' | head     -> 0 lines of output
$ git log -p --all -S'<staging DB_USER value>' | head     -> 0 lines of output
$ git log -p --all -S'<staging DB_PASSWORD value>' | head     -> 0 lines of output
# (POSTGRES_USER/POSTGRES_PASSWORD carry the same values as DB_USER/DB_PASSWORD, so they are covered)

$ git status --short --ignored
?? argocd/applications/tasktracker-dev.yaml
?? argocd/applications/tasktracker-staging.yaml
?? charts/tasktracker/templates/smoke-test-job.yaml
!! secrets-plain/
```

Keys tested: `DB_USER` and `DB_PASSWORD` for dev and for staging. These are all four distinct values; `POSTGRES_USER` and `POSTGRES_PASSWORD` carry the same values. Every search printed nothing. `secrets-plain/` appears only as ignored (`!!`).

---

## Task 5: Deliver the Workloads to dev and staging

### Image pull note
The first dev sync stalled with `ImagePullBackOff` on `db-0`. The cause was `no match for platform in manifest: not found` when pulling `sarojsanyasi/dso202-db:1.0` from Docker Hub. As described in section 13 of the brief, the three issued `1.0` images were loaded into the node from the host. The tags and the `IfNotPresent` pull policy were not changed:

```text
$ kind load docker-image sarojsanyasi/dso202-db:1.0 sarojsanyasi/dso202-backend:1.0 sarojsanyasi/dso202-frontend:1.0 --name dso202-gitops
```

### Application states while dev deployed (watch, with local time)

```text
01:22:22 NAME               SYNC STATUS   HEALTH STATUS
01:22:22 platform-dev       Synced        Healthy
01:22:22 platform-staging   Synced        Healthy
01:22:22 root               Synced        Healthy
01:22:22 sealed-secrets     Synced        Healthy
01:22:22 sealed-secrets     Synced        Healthy
01:22:27 root               Synced        Healthy
01:22:32 root               Synced        Healthy
01:22:32 root               Synced        Healthy
01:22:32 root               OutOfSync     Healthy
01:22:35 root               OutOfSync     Healthy
01:22:37 root               OutOfSync     Healthy
01:22:39 root               OutOfSync     Healthy
01:22:39 tasktracker-staging                 
01:22:39 tasktracker-dev                     
01:22:39 root                  OutOfSync     Healthy
01:22:39 root                  OutOfSync     Healthy
01:22:39 root                  Synced        Progressing
01:22:39 root                  Synced        Progressing
01:22:41 tasktracker-dev                     
01:22:41 tasktracker-dev                     
01:22:41 tasktracker-dev       OutOfSync     Missing
01:22:42 tasktracker-dev       OutOfSync     Healthy
01:22:42 tasktracker-dev       OutOfSync     Progressing
01:22:44 tasktracker-dev       OutOfSync     Progressing
01:22:44 tasktracker-dev       OutOfSync     Progressing
01:22:44 tasktracker-staging   OutOfSync     Missing
01:23:21 platform-staging      Synced        Healthy
01:23:25 platform-dev          Synced        Healthy
01:23:26 sealed-secrets        Synced        Healthy
01:23:44 tasktracker-dev       OutOfSync     Progressing
01:24:20 tasktracker-staging   OutOfSync     Missing
01:24:20 root                  Synced        Progressing
01:24:24 platform-staging      Synced        Healthy
01:24:26 sealed-secrets        Synced        Healthy
01:24:27 platform-dev          Synced        Healthy
01:25:02 tasktracker-dev       OutOfSync     Progressing
01:25:19 root                  Synced        Progressing
01:25:22 tasktracker-staging   OutOfSync     Missing
01:25:27 platform-dev          Synced        Healthy
01:26:18 tasktracker-dev       OutOfSync     Progressing
01:26:21 platform-staging      Synced        Healthy
01:26:25 tasktracker-staging   OutOfSync     Missing
01:26:26 root                  Synced        Progressing
01:26:26 sealed-secrets        Synced        Healthy
01:27:19 tasktracker-dev       OutOfSync     Progressing
01:27:25 tasktracker-staging   OutOfSync     Missing
01:27:28 platform-dev          Synced        Healthy
01:28:22 sealed-secrets        Synced        Healthy
01:28:23 tasktracker-dev       OutOfSync     Progressing
01:28:24 platform-staging      Synced        Healthy
01:28:24 root                  Synced        Progressing
```

### Pod creation order in dev (watch, with local time)
Before the image load (db-0 created in wave 0, nothing else created while it was not ready):

```text
01:22:42 NAME   READY   STATUS    RESTARTS   AGE
01:22:42 db-0   0/1     Pending   0          0s
01:22:42 db-0   0/1     Pending   0          0s
01:22:46 db-0   0/1     Pending   0          4s
01:22:46 db-0   0/1     ContainerCreating   0          4s
01:22:47 db-0   0/1     ContainerCreating   0          5s
```

After the image load:

```text
01:29:11 NAME   READY   STATUS    RESTARTS   AGE
01:29:11 db-0   0/1     Running   0          6m29s
01:29:13 db-0   1/1     Running   0          6m31s
01:29:13 db-0   1/1     Running   0          6m31s
01:29:14 backend-d666f4fd-j5ltm   0/1     Pending   0          0s
01:29:14 backend-d666f4fd-j5ltm   0/1     Pending   0          0s
01:29:14 backend-d666f4fd-j5ltm   0/1     ContainerCreating   0          0s
01:29:14 backend-d666f4fd-j5ltm   0/1     ContainerCreating   0          0s
01:29:14 backend-d666f4fd-j5ltm   0/1     Running             0          0s
01:29:19 backend-d666f4fd-j5ltm   1/1     Running             0          5s
01:29:19 backend-d666f4fd-j5ltm   1/1     Running             0          5s
01:29:20 frontend-f5bbcbb78-45sc7   0/1     Pending             0          0s
01:29:20 frontend-f5bbcbb78-45sc7   0/1     Pending             0          0s
01:29:20 frontend-f5bbcbb78-45sc7   0/1     ContainerCreating   0          0s
01:29:20 frontend-f5bbcbb78-45sc7   0/1     ContainerCreating   0          0s
01:29:20 frontend-f5bbcbb78-45sc7   0/1     Running             0          0s
01:29:20 frontend-f5bbcbb78-45sc7   1/1     Running             0          0s
01:29:22 tasktracker-smoke-test-j7c64   0/1     Pending             0          0s
01:29:22 tasktracker-smoke-test-j7c64   0/1     Pending             0          0s
01:29:22 tasktracker-smoke-test-j7c64   0/1     ContainerCreating   0          0s
01:29:23 tasktracker-smoke-test-j7c64   0/1     ContainerCreating   0          1s
01:29:36 tasktracker-smoke-test-j7c64   1/1     Running             0          14s
01:29:36 tasktracker-smoke-test-j7c64   0/1     Completed           0          14s
01:29:37 tasktracker-smoke-test-j7c64   0/1     Completed           0          15s
01:29:37 tasktracker-smoke-test-j7c64   0/1     Completed           0          15s
01:29:38 tasktracker-smoke-test-j7c64   0/1     Completed           0          16s
01:30:30 frontend-f5bbcbb78-45sc7       1/1     Running             0          70s
```

Order: `db-0` ready at 01:29:13, then `backend` created at 01:29:14 and ready at 01:29:19, then `frontend` created at 01:29:20, then the PostSync smoke test at 01:29:22, completed at 01:29:36. These are waves 0, 1 and 2, followed by the hook.

### Smoke test, `argocd app get`, frontend, and CRUD in dev

```text
$ kubectl get job -n dso202-dev
NAME                     STATUS     COMPLETIONS   DURATION   AGE
tasktracker-smoke-test   Complete   1/1           16s        32s

$ kubectl logs job/tasktracker-smoke-test -n dso202-dev
[{"id":1,"title":"Set up kind cluster","description":"Bring up the local cluster from Practical 1","status":"done","created_at":"2026-11-24T19:29:10.235Z"},{"id":2,"title":"Write namespace manifest","description":"One namespace for all assignment resources","status":"in_progress","created_at":"2026-11-24T19:29:10.235Z"},{"id":3,"title":"Wire ConfigMap and Secret","description":"DB_* and POSTGRES_* must carry matching values","status":"pending","created_at":"2026-11-24T19:29:10.235Z"}]
$ argocd app get tasktracker-dev
Name:               argocd/tasktracker-dev
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-dev
URL:                https://localhost:8080/applications/tasktracker-dev
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           main
  Path:             charts/tasktracker
  Helm Values:      ../../environments/dev/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (86bd5bb)
Health Status:      Healthy

GROUP  KIND            NAMESPACE   NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-dev  db-config               Synced                        configmap/db-config created
       Service         dso202-dev  db                      Synced     Healthy            service/db created
apps   StatefulSet     dso202-dev  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7cb8df4897...
       ServiceAccount  dso202-dev  backend-sa              Synced                        serviceaccount/backend-sa created
       ConfigMap       dso202-dev  backend-config          Synced                        configmap/backend-config created
       Service         dso202-dev  backend                 Synced     Healthy            service/backend created
apps   Deployment      dso202-dev  backend                 Synced     Healthy            deployment.apps/backend created
       ConfigMap       dso202-dev  frontend-config         Synced                        configmap/frontend-config created
       Service         dso202-dev  frontend                Synced     Healthy            service/frontend created
apps   Deployment      dso202-dev  frontend                Synced     Healthy            deployment.apps/frontend created
batch  Job             dso202-dev  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ curl -s -o /dev/null -w 'HTTP %{http_code}
' http://localhost:30080/
HTTP 200

$ curl -s http://localhost:30080/ | grep -i '<title>'
<title>Field Log — Task Tracker</title>

# CRUD cycle in dev through: kubectl port-forward -n dso202-dev svc/backend 18080:8080
$ curl -s http://localhost:18080/api/status
{"status":"ok","db":"connected"}
$ curl -s -X POST -H 'Content-Type: application/json' -d '{"title":"Task 5 CRUD check (dev)"}' http://localhost:18080/api/tasks
{"id":4,"title":"Task 5 CRUD check (dev)","description":null,"status":"pending","created_at":"2026-11-24T19:29:54.315Z"}
$ curl -s http://localhost:18080/api/tasks/4
{"id":4,"title":"Task 5 CRUD check (dev)","description":null,"status":"pending","created_at":"2026-11-24T19:29:54.315Z"}
$ curl -s http://localhost:18080/api/tasks
[{"id":1,"title":"Set up kind cluster","description":"Bring up the local cluster from Practical 1","status":"done","created_at":"2026-11-24T19:29:10.235Z"},{"id":2,"title":"Write namespace manifest","description":"One namespace for all assignment resources","status":"in_progress","created_at":"2026-11-24T19:29:10.235Z"},{"id":3,"title":"Wire ConfigMap and Secret","description":"DB_* and POSTGRES_* must carry matching values","status":"pending","created_at":"2026-11-24T19:29:10.235Z"},{"id":4,"title":"Task 5 CRUD check (dev)","description":null,"status":"pending","created_at":"2026-11-24T19:29:54.315Z"}]
$ curl -s -X PUT -H 'Content-Type: application/json' -d '{"status":"done"}' http://localhost:18080/api/tasks/4
{"id":4,"title":"Task 5 CRUD check (dev)","description":null,"status":"done","created_at":"2026-11-24T19:29:54.315Z"}
$ curl -s -o /dev/null -w 'HTTP %{http_code}
' -X DELETE http://localhost:18080/api/tasks/4
HTTP 204

$ curl -s -o /dev/null -w 'HTTP %{http_code}
' http://localhost:18080/api/tasks/4
HTTP 404
```

The frontend answers on `http://localhost:30080` (HTTP 200).

The CRUD cycle was run with `curl` through a port-forwarded backend: create (id 4), read, list, update to `done`, delete (204), then read again (404). This is the same method as Assignment 1. The frontend image calls the API from the browser and its nginx does not proxy `/api`, so in-browser CRUD needs a backend reachable from the browser, which this NodePort-only design does not provide. The page itself is shown in `docs/screenshots/task5-dev-frontend.png`.

### Staging: before and after the first manual sync

```text
# Root Application BEFORE the first staging sync
$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Healthy
tasktracker-staging   OutOfSync     Missing

$ argocd app get tasktracker-staging
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.0.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from v1.0.0 (10e828a)
Health Status:      Missing

GROUP  KIND            NAMESPACE       NAME             STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap       dso202-staging  backend-config   OutOfSync  Missing        
       ConfigMap       dso202-staging  db-config        OutOfSync  Missing        
       ConfigMap       dso202-staging  frontend-config  OutOfSync  Missing        
       Service         dso202-staging  backend          OutOfSync  Missing        
       Service         dso202-staging  db               OutOfSync  Missing        
       Service         dso202-staging  frontend         OutOfSync  Missing        
       ServiceAccount  dso202-staging  backend-sa       OutOfSync  Missing        
apps   Deployment      dso202-staging  backend          OutOfSync  Missing        
apps   Deployment      dso202-staging  frontend         OutOfSync  Missing        
apps   StatefulSet     dso202-staging  db               OutOfSync  Missing        

$ argocd app get root | sed -n '/^GROUP/,$p'
GROUP        KIND         NAMESPACE  NAME                 STATUS  HEALTH   HOOK  MESSAGE
argoproj.io  AppProject   argocd     dso202               Synced                 appproject.argoproj.io/dso202 unchanged
argoproj.io  Application  argocd     sealed-secrets       Synced  Healthy        application.argoproj.io/sealed-secrets unchanged
argoproj.io  Application  argocd     platform-staging     Synced  Healthy        application.argoproj.io/platform-staging unchanged
argoproj.io  Application  argocd     platform-dev         Synced  Healthy        application.argoproj.io/platform-dev unchanged
argoproj.io  Application  argocd     tasktracker-staging  Synced  Missing        application.argoproj.io/tasktracker-staging created
argoproj.io  Application  argocd     tasktracker-dev      Synced  Healthy        application.argoproj.io/tasktracker-dev created

$ argocd app sync tasktracker-staging --timeout 300 | tail -20
Operation:          Sync
Sync Revision:      10e828a4561247f2d9d2d29908673a291c0a51f0
Phase:              Succeeded
Start:              2026-11-25 01:30:18 +0600 +06
Finished:           2026-11-25 01:30:41 +0600 +06
Duration:           23s
Message:            successfully synced (no more tasks)

GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config created
       Service         dso202-staging  db                      Synced     Healthy            service/db created
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa created
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config created
       Service         dso202-staging  backend                 Synced     Healthy            service/backend created
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend created
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config created
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend created
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend created
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ argocd app wait tasktracker-staging --health --timeout 300

Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.0.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        Synced to v1.0.0 (10e828a)
Health Status:      Healthy


GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config created
       Service         dso202-staging  db                      Synced     Healthy            service/db created
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa created
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config created
       Service         dso202-staging  backend                 Synced     Healthy            service/backend created
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend created
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config created
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend created
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend created
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

# Root Application AFTER the first staging sync
$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Healthy
tasktracker-staging   Synced        Healthy

$ argocd app get tasktracker-staging | sed -n '/^Sync Policy/,$p'
Sync Policy:        Manual
Sync Status:        Synced to v1.0.0 (10e828a)
Health Status:      Healthy

GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config created
       Service         dso202-staging  db                      Synced     Healthy            service/db created
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa created
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config created
       Service         dso202-staging  backend                 Synced     Healthy            service/backend created
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend created
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config created
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend created
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend created
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ kubectl get svc -n dso202-staging
NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
backend    ClusterIP   10.96.105.97   <none>        8080/TCP         15s
db         ClusterIP   None           <none>        5432/TCP         25s
frontend   NodePort    10.96.110.22   <none>        8080:30081/TCP   9s

$ kubectl logs job/tasktracker-smoke-test -n dso202-staging
[{"id":1,"title":"Set up kind cluster","description":"Bring up the local cluster from Practical 1","status":"done","created_at":"2026-11-24T19:30:26.195Z"},{"id":2,"title":"Write namespace manifest","description":"One namespace for all assignment resources","status":"in_progress","created_at":"2026-11-24T19:30:26.195Z"},{"id":3,"title":"Wire ConfigMap and Secret","description":"DB_* and POSTGRES_* must carry matching values","status":"pending","created_at":"2026-11-24T19:30:26.195Z"}]
$ kubectl port-forward -n dso202-staging svc/frontend 8081:8080   (in another terminal)
$ curl -s -o /dev/null -w "HTTP %{http_code}
" http://localhost:8081/
HTTP 200
```

**Observation on the root Application.** The brief expected `root` to stay `Progressing` until staging had been synchronised once. In this run the child's health was correctly reported upward as `Missing` (see `argocd app get root` above). The `root` itself still reported `Healthy`, because Argo CD's application health calculation does not count a child Application whose health is `Missing` or `Unknown`. The restored health check does work for real states: in the watch above, `root` went `Synced / Progressing` at 01:22:39 while `tasktracker-dev` was `Progressing`.

Screenshot: `docs/screenshots/task5-dev-tree.png` (`tasktracker-dev` resource tree).

---

## Task 6: Access Control for Argo CD Users

```text
$ argocd account list
NAME      ENABLED  CAPABILITIES
admin     true     login
reviewer  true     login

$ argocd account update-password --account reviewer     (passwords entered at the prompts; not recorded)
Password updated

$ argocd login localhost:8080 --username reviewer --insecure --name reviewer
'reviewer:login' logged in successfully
Context 'reviewer' updated

$ argocd --argocd-context reviewer app list
NAME                        CLUSTER                         NAMESPACE       PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                              PATH                TARGET
argocd/tasktracker-dev      https://kubernetes.default.svc  dso202-dev      dso202   Synced  Healthy  Auto-Prune  <none>      https://github.com/Kinley-pal8/dso202-gitops.git  charts/tasktracker  main
argocd/tasktracker-staging  https://kubernetes.default.svc  dso202-staging  dso202   Synced  Healthy  Manual      <none>      https://github.com/Kinley-pal8/dso202-gitops.git  charts/tasktracker  v1.0.0

$ argocd --argocd-context reviewer account can-i get applications 'dso202/tasktracker-dev'
yes

$ argocd --argocd-context reviewer account can-i sync applications 'dso202/tasktracker-dev'
no

$ argocd --argocd-context reviewer account can-i get logs 'dso202/tasktracker-dev'
no

$ argocd --argocd-context reviewer proj get platform
{"level":"fatal","msg":"rpc error: code = PermissionDenied desc = permission denied: projects, get, platform, sub: reviewer, iat: 2026-11-24T19:30:57Z","time":"2026-11-25T01:30:57+06:00"}

$ git show --stat --oneline HEAD | head -3
ce5872c Grant reviewer read access to logs in the dso202 project (Task 6, step 4)
 bootstrap/argocd/argocd-rbac-cm-patch.yaml | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git show HEAD | grep '^[-+]    '
-    # p, reviewer, logs, get, dso202/*, allow
+    p, reviewer, logs, get, dso202/*, allow

$ kubectl apply -k bootstrap/argocd --server-side --force-conflicts | grep -E 'argocd-rbac-cm|argocd-cm '
configmap/argocd-cm serverside-applied
configmap/argocd-rbac-cm serverside-applied

$ argocd --argocd-context reviewer account can-i get logs 'dso202/tasktracker-dev'
yes
```

The reviewer password was set interactively and is kept outside the repository. Before the commit, `can-i get logs` answered `no`. After the commit and the re-apply of the bootstrap layer it answered `yes`. The other results matched the expectations: two Applications listed, `get` yes, `sync` no, and `platform` denied.

Screenshot: `docs/screenshots/task6-reviewer-logs.png` (reviewer session in a private window showing Pod logs).

---

## Task 7: A Release, a Faulty Release, and Recovery

**Pending.** The tutor-issued `sarojsanyasi/dso202-frontend:1.1` and `sarojsanyasi/dso202-backend:1.1` images were not available on Docker Hub when Tasks 1 to 6 were completed (25 November 2026). Only tag `1.0` exists.

## Task 8: Drift, Pruning and Project Guardrails

**Pending.** Done after Task 7, as the brief requires the tasks in order.

## Task 9: Rebuild from Git

**Pending.** Done after Task 8.
