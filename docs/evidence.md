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

### Images used for the release

The tutor-issued `sarojsanyasi/dso202-frontend:1.1` and `sarojsanyasi/dso202-backend:1.1` tags were never published on Docker Hub; only `1.0` exists. The module tutor instructed me to build my own. The source is in [`stand-in-images/`](../stand-in-images/README.md), built from the `1.0` source of Assignment 1. The images are tagged `dso202-local/dso202-{frontend,backend}:1.1` and loaded into the kind node with `kind load docker-image`, so they cannot be mistaken for the tutor's images. Each one matches its section 8 release note:

- **Frontend 1.1:** the page header shows `release 1.1`; nothing else changes.
- **Backend 1.1:** configuration loading is refactored into `src/config.js`, and the API is unchanged. The new loader also requires `DB_POOL_MAX`, which the release note does not mention. Without it the process exits at start-up, as a Task 7 backend is meant to.

Because the repository changes as well as the tag, each release changes `image.repository` and `image.tag` in the values files. This is still a values-only change (C1).

### Pull requests

All six changes were made on a branch and merged through a GitHub pull request. GitHub's "Create a merge commit" was used instead of squash merging, so each pull request is a branch commit plus a merge commit on `main`. The revert therefore needed `git revert -m 1`, as the brief describes. A screenshot of the pull request list is `docs/screenshots/task7-pull-requests.png`.

| PR | Branch | Change | Merge commit on `main` |
|---|---|---|---|
| #1 | `release/frontend-1.1` | Frontend `1.1` in both values files | `3c1879a` (tag `v1.1.0`) |
| #2 | `promote/staging-v1.1.0` | Staging `targetRevision` `v1.0.0` to `v1.1.0` | `df1dde2` |
| #3 | `release/backend-1.1` | Backend `1.1` in both values files: **the bad commit** | `0a3267f` |
| #4 | `revert/backend-1.1` | `git revert -m 1 0a3267f` | `91ce0d7` |
| #5 | `fix/backend-1.1-pool-max` | Backend `1.1` again, plus `backend.config.DB_POOL_MAX: "10"` | `95717b8` (tag `v1.2.0`) |
| #6 | `promote/staging-v1.2.0` | Staging `targetRevision` `v1.1.0` to `v1.2.0` | `08e5e1b` |

```text
$ git log --oneline --graph --decorate -n 15
*   08e5e1b (HEAD -> main, origin/main, origin/HEAD) Merge pull request #6 from Kinley-pal8/promote/staging-v1.2.0
|\  
| * 996b299 (origin/promote/staging-v1.2.0, promote/staging-v1.2.0) Promote staging to v1.2.0 (backend 1.1 with DB_POOL_MAX)
|/  
*   95717b8 (tag: v1.2.0) Merge pull request #5 from Kinley-pal8/fix/backend-1.1-pool-max
|\  
| * 6b4b86a (origin/fix/backend-1.1-pool-max, fix/backend-1.1-pool-max) Fix forward: backend 1.1 with DB_POOL_MAX supplied as a value (C2)
|/  
*   91ce0d7 Merge pull request #4 from Kinley-pal8/revert/backend-1.1
|\  
| * e8342ec (origin/revert/backend-1.1, revert/backend-1.1) Revert "Merge pull request #3 from Kinley-pal8/release/backend-1.1"
|/  
*   0a3267f Merge pull request #3 from Kinley-pal8/release/backend-1.1
|\  
| * c94a6a5 (origin/release/backend-1.1, release/backend-1.1) Release backend 1.1 to dev (staging values updated, gated by tag)
|/  
*   df1dde2 Merge pull request #2 from Kinley-pal8/promote/staging-v1.1.0
|\  
| * 027c1fe (origin/promote/staging-v1.1.0, promote/staging-v1.1.0) Promote staging to v1.1.0 (frontend 1.1)
|/  
*   3c1879a (tag: v1.1.0) Merge pull request #1 from Kinley-pal8/release/frontend-1.1
|\  
| * 2de323a (origin/release/frontend-1.1, release/frontend-1.1) Release frontend 1.1 to dev (staging values updated, gated by tag)
|/  
* c8653c9 Add source for stand-in 1.1 frontend and backend images (tutor-approved; 1.1 tags not published)
* ac9420e Add README (versions, bootstrap, credentials, Q1-Q4) and evidence for Tasks 1-6
* ce5872c Grant reviewer read access to logs in the dso202 project (Task 6, step 4)
```

### Part A, steps 1 and 2: frontend 1.1 reaches dev

Pull request #1 was merged at about 22:31. The dev Pods were watched with local timestamps:

```text
22:31:47 EVENT      NAME                           READY   STATUS      RESTARTS      AGE
22:31:47 ADDED      backend-d666f4fd-j5ltm         1/1     Running     2 (25m ago)   2d21h
22:31:47 ADDED      db-0                           1/1     Running     2 (25m ago)   2d21h
22:31:47 ADDED      frontend-f5bbcbb78-45sc7       1/1     Running     2 (25m ago)   2d21h
22:31:47 ADDED      tasktracker-smoke-test-j7c64   0/1     Completed   0             2d21h
22:31:48 ADDED      frontend-698c7d47fb-wc8cf      0/1     Pending     0             0s
22:31:48 MODIFIED   frontend-698c7d47fb-wc8cf      0/1     Pending     0             0s
22:31:48 MODIFIED   frontend-698c7d47fb-wc8cf      0/1     ContainerCreating   0             0s
22:31:49 MODIFIED   frontend-698c7d47fb-wc8cf      0/1     ContainerCreating   0             1s
22:31:49 MODIFIED   frontend-698c7d47fb-wc8cf      0/1     Running             0             1s
22:31:49 MODIFIED   frontend-698c7d47fb-wc8cf      1/1     Running             0             1s
22:31:49 MODIFIED   frontend-f5bbcbb78-45sc7       1/1     Terminating         2 (25m ago)   2d21h
22:31:49 MODIFIED   frontend-f5bbcbb78-45sc7       1/1     Terminating         2 (25m ago)   2d21h
22:31:49 MODIFIED   frontend-f5bbcbb78-45sc7       0/1     Completed           2 (25m ago)   2d21h
22:31:50 MODIFIED   frontend-698c7d47fb-wc8cf      1/1     Running             0             2s
22:31:50 MODIFIED   frontend-f5bbcbb78-45sc7       0/1     Completed           2 (25m ago)   2d21h
22:31:50 DELETED    frontend-f5bbcbb78-45sc7       0/1     Completed           2 (25m ago)   2d21h
22:31:50 MODIFIED   tasktracker-smoke-test-j7c64   0/1     Completed           0             2d21h
22:31:50 DELETED    tasktracker-smoke-test-j7c64   0/1     Completed           0             2d21h
22:31:50 ADDED      tasktracker-smoke-test-rhnrq   0/1     Pending             0             0s
22:31:50 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     Pending             0             0s
22:31:50 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     ContainerCreating   0             0s
22:31:51 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     ContainerCreating   0             1s
22:31:52 MODIFIED   tasktracker-smoke-test-rhnrq   1/1     Running             0             2s
22:31:53 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     Completed           0             3s
22:31:54 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     Completed           0             4s
22:31:54 MODIFIED   tasktracker-smoke-test-rhnrq   0/1     Completed           0             4s
```

```text
$ curl -s http://localhost:30080 | grep -o '<p class="subhead">.*</p>'
<p class="subhead">task tracker &mdash; unit i deployment demo &middot; <span class="release-tag">release 1.1</span></p>

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
Sync Status:        Synced to main (3c1879a)
Health Status:      Healthy
GROUP  KIND            NAMESPACE   NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-dev  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-dev  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-dev  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7cb8df4897...
       ServiceAccount  dso202-dev  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-dev  backend-config          Synced                        configmap/backend-config unchanged
       Service         dso202-dev  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-dev  backend                 Synced     Healthy            deployment.apps/backend unchanged
       ConfigMap       dso202-dev  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-dev  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-dev  frontend                Synced     Healthy            deployment.apps/frontend configured
batch  Job             dso202-dev  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ argocd app history tasktracker-dev
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:29:39 +0600 +06  main (86bd5bb)
1       2026-11-27 22:31:54 +0600 +06  main (3c1879a)

$ kubectl get deploy frontend -n dso202-dev -o jsonpath='{..image}'
dso202-local/dso202-frontend:1.1
```

The frontend rolled in about two seconds: the new Pod became ready, then the old one was removed. The PostSync smoke test then ran again and succeeded. The page header shows `release 1.1`. The database and backend were left `unchanged`.

### Part A, step 3: promotion to staging through tag `v1.1.0`

```text
$ git tag -a v1.1.0 -m "Release: frontend 1.1"      # on 3c1879a
$ git push origin v1.1.0
# then pull request #2 (targetRevision: v1.1.0), merged as df1dde2
```

After root applied the changed Application, staging was `OutOfSync` but did not deploy, because it has no automated sync:

```text
$ argocd app get tasktracker-staging --refresh
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.1.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from v1.1.0 (3c1879a)
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
apps   Deployment      dso202-staging  frontend                OutOfSync  Healthy            deployment.apps/frontend created
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods
```

```text
# Before the sync, through kubectl port-forward svc/frontend -n dso202-staging 8081:8080
$ curl -s http://localhost:8081 | grep -o '<p class="subhead">.*</p>'
<p class="subhead">task tracker &mdash; unit i deployment demo</p>

$ argocd app sync tasktracker-staging
TIMESTAMP                  GROUP        KIND       NAMESPACE                      NAME      STATUS    HEALTH        HOOK  MESSAGE
2026-11-27T22:40:31+06:00   apps  Deployment      dso202-staging               backend      Synced   Healthy              
2026-11-27T22:40:31+06:00          ConfigMap      dso202-staging        backend-config      Synced                        
2026-11-27T22:40:31+06:00            Service      dso202-staging                    db      Synced   Healthy              
2026-11-27T22:40:31+06:00            Service      dso202-staging              frontend      Synced   Healthy              
2026-11-27T22:40:31+06:00         ServiceAccount  dso202-staging            backend-sa      Synced                        
2026-11-27T22:40:31+06:00   apps  Deployment      dso202-staging              frontend    OutOfSync  Healthy              
2026-11-27T22:40:31+06:00   apps  StatefulSet     dso202-staging                    db      Synced   Healthy              
2026-11-27T22:40:31+06:00  batch         Job      dso202-staging  tasktracker-smoke-test             Healthy              
2026-11-27T22:40:31+06:00          ConfigMap      dso202-staging             db-config      Synced                        
2026-11-27T22:40:31+06:00          ConfigMap      dso202-staging       frontend-config      Synced                        
2026-11-27T22:40:31+06:00            Service      dso202-staging               backend      Synced   Healthy              
2026-11-27T22:40:34+06:00   apps  StatefulSet  dso202-staging                    db    Synced  Healthy              statefulset.apps/db configured
2026-11-27T22:40:34+06:00          ConfigMap   dso202-staging             db-config    Synced                       configmap/db-config unchanged
2026-11-27T22:40:34+06:00            Service   dso202-staging                    db    Synced  Healthy              service/db unchanged
2026-11-27T22:40:36+06:00         ServiceAccount  dso202-staging            backend-sa    Synced                       serviceaccount/backend-sa unchanged
2026-11-27T22:40:36+06:00          ConfigMap      dso202-staging        backend-config    Synced                       configmap/backend-config unchanged
2026-11-27T22:40:36+06:00            Service      dso202-staging               backend    Synced  Healthy              service/backend unchanged
2026-11-27T22:40:36+06:00   apps  Deployment      dso202-staging               backend    Synced  Healthy              deployment.apps/backend unchanged
2026-11-27T22:40:36+06:00   apps  StatefulSet     dso202-staging                    db    Synced  Healthy              statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
2026-11-27T22:40:36+06:00   apps  Deployment  dso202-staging              frontend    Synced  Progressing              
2026-11-27T22:40:37+06:00   apps  Deployment  dso202-staging              frontend    Synced  Healthy              
2026-11-27T22:40:38+06:00            Service  dso202-staging              frontend    Synced  Healthy              service/frontend unchanged
2026-11-27T22:40:38+06:00   apps  Deployment  dso202-staging              frontend    Synced  Healthy              deployment.apps/frontend configured
2026-11-27T22:40:38+06:00          ConfigMap  dso202-staging       frontend-config    Synced                       configmap/frontend-config unchanged
2026-11-27T22:40:38+06:00  batch         Job  dso202-staging  tasktracker-smoke-test            Progressing              
2026-11-27T22:40:38+06:00  batch         Job  dso202-staging  tasktracker-smoke-test   Running   Synced    PostSync  job.batch/tasktracker-smoke-test created
2026-11-27T22:40:38+06:00  batch         Job  dso202-staging  tasktracker-smoke-test   Running   Synced    PostSync  Pending deletion
2026-11-27T22:40:42+06:00  batch         Job  dso202-staging  tasktracker-smoke-test  Succeeded   Synced    PostSync  Reached expected number of succeeded pods
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.1.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        Synced to v1.1.0 (3c1879a)
Health Status:      Healthy
Operation:          Sync
Sync Revision:      3c1879aa4e4f100c4f3a88c8c62951160d2901b0
Phase:              Succeeded
Start:              2026-11-27 22:40:31 +0600 +06
Finished:           2026-11-27 22:40:42 +0600 +06
Duration:           11s
Message:            successfully synced (no more tasks)
GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-staging  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config unchanged
       Service         dso202-staging  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend unchanged
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend configured
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

# After the sync
$ curl -s http://localhost:8081 | grep -o '<p class="subhead">.*</p>'
<p class="subhead">task tracker &mdash; unit i deployment demo &middot; <span class="release-tag">release 1.1</span></p>

$ argocd app history tasktracker-staging
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:30:41 +0600 +06  v1.0.0 (10e828a)
1       2026-11-27 22:40:42 +0600 +06  v1.1.0 (3c1879a)
```

Staging showed the old header until a person ran the sync. After the sync it shows `release 1.1`, and its smoke test passed.

### Part B, step 4: backend 1.1 (the bad commit)

Pull request #3 changed the backend in both values files and was merged as **`0a3267f`**, the bad commit. Staging was unaffected: it reads tag `v1.1.0`.

### Part B, step 5: observation without intervention

Dev Pods (watch, local time). The new backend Pod `backend-664d47bfd-827vg` is created and crashes; the old `backend-d666f4fd-j5ltm` keeps running:

```text
22:40:59 EVENT      NAME                           READY   STATUS      RESTARTS      AGE
22:40:59 ADDED      backend-d666f4fd-j5ltm         1/1     Running     2 (34m ago)   2d21h
22:40:59 ADDED      db-0                           1/1     Running     2 (34m ago)   2d21h
22:40:59 ADDED      frontend-698c7d47fb-wc8cf      1/1     Running     0             9m11s
22:40:59 ADDED      tasktracker-smoke-test-rhnrq   0/1     Completed   0             9m9s
22:44:32 ADDED      backend-664d47bfd-827vg        0/1     Pending     0             0s
22:44:32 MODIFIED   backend-664d47bfd-827vg        0/1     Pending     0             0s
22:44:32 MODIFIED   backend-664d47bfd-827vg        0/1     ContainerCreating   0             0s
22:44:33 MODIFIED   backend-664d47bfd-827vg        0/1     ContainerCreating   0             1s
22:44:33 MODIFIED   backend-664d47bfd-827vg        0/1     Running             0             1s
22:44:34 MODIFIED   backend-664d47bfd-827vg        0/1     Error               0             2s
22:44:34 MODIFIED   backend-664d47bfd-827vg        0/1     Running             1 (1s ago)    2s
22:44:35 MODIFIED   backend-664d47bfd-827vg        0/1     Error               1 (2s ago)    3s
22:44:36 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    1 (2s ago)    4s
22:44:45 MODIFIED   backend-664d47bfd-827vg        0/1     Running             2 (11s ago)   13s
22:44:46 MODIFIED   backend-664d47bfd-827vg        0/1     Error               2 (12s ago)   14s
22:44:47 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    2 (2s ago)    15s
22:45:13 MODIFIED   backend-664d47bfd-827vg        0/1     Running             3 (28s ago)   41s
22:45:14 MODIFIED   backend-664d47bfd-827vg        0/1     Error               3 (29s ago)   42s
22:45:15 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    3 (2s ago)    43s
22:46:09 MODIFIED   backend-664d47bfd-827vg        0/1     Running             4 (56s ago)   97s
22:46:10 MODIFIED   backend-664d47bfd-827vg        0/1     Error               4 (57s ago)   98s
22:46:11 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    4 (2s ago)    99s
22:47:31 MODIFIED   backend-664d47bfd-827vg        0/1     Running             5 (82s ago)   2m59s
22:47:32 MODIFIED   backend-664d47bfd-827vg        0/1     Error               5 (83s ago)   3m
22:48:34 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    5 (63s ago)   4m2s
22:50:18 MODIFIED   backend-664d47bfd-827vg        0/1     Running             6 (2m47s ago)   5m46s
22:50:19 MODIFIED   backend-664d47bfd-827vg        0/1     Error               6 (2m48s ago)   5m47s
22:50:20 MODIFIED   backend-664d47bfd-827vg        0/1     CrashLoopBackOff    6 (2s ago)      5m48s
```

Application states (watch, local time, transitions only):

```text
22:44:30 tasktracker-dev       OutOfSync     Healthy
22:44:33 tasktracker-dev       Synced        Progressing
22:44:33 root                  Synced        Progressing
22:46:33 tasktracker-dev       Synced        Degraded
22:46:33 root                  Synced        Degraded
22:51:03 tasktracker-dev       OutOfSync     Degraded
22:54:57 tasktracker-dev       Synced        Healthy
22:54:57 root                  Synced        Healthy
22:59:38 tasktracker-dev       OutOfSync     Healthy
22:59:41 tasktracker-dev       Synced        Progressing
22:59:41 root                  Synced        Progressing
22:59:42 tasktracker-dev       Synced        Healthy
22:59:42 root                  Synced        Healthy
```

```text
$ kubectl get pods -n dso202-dev        # at 22:46:46, 2 min 14 s after the new Pod was created
NAME                           READY   STATUS             RESTARTS      AGE     IP            NODE                          NOMINATED NODE   READINESS GATES
backend-664d47bfd-827vg        0/1     CrashLoopBackOff   4 (37s ago)   2m14s   10.244.0.23   dso202-gitops-control-plane   <none>           <none>
backend-d666f4fd-j5ltm         1/1     Running            2 (40m ago)   2d21h   10.244.0.14   dso202-gitops-control-plane   <none>           <none>
db-0                           1/1     Running            2 (40m ago)   2d21h   10.244.0.11   dso202-gitops-control-plane   <none>           <none>
frontend-698c7d47fb-wc8cf      1/1     Running            0             14m     10.244.0.19   dso202-gitops-control-plane   <none>           <none>
tasktracker-smoke-test-rhnrq   0/1     Completed          0             14m     10.244.0.20   dso202-gitops-control-plane   <none>           <none>

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
Sync Status:        Synced to main (0a3267f)
Health Status:      Degraded
GROUP  KIND            NAMESPACE   NAME                    STATUS  HEALTH    HOOK  MESSAGE
       ConfigMap       dso202-dev  db-config               Synced                  configmap/db-config unchanged
       Service         dso202-dev  db                      Synced  Healthy         service/db unchanged
apps   StatefulSet     dso202-dev  db                      Synced  Healthy         statefulset rolling update complete 1 pods at revision db-7cb8df4897...
       ServiceAccount  dso202-dev  backend-sa              Synced                  serviceaccount/backend-sa unchanged
       ConfigMap       dso202-dev  backend-config          Synced                  configmap/backend-config unchanged
       Service         dso202-dev  backend                 Synced  Healthy         service/backend unchanged
apps   Deployment      dso202-dev  backend                 Synced  Degraded        Deployment "backend" exceeded its progress deadline
       ConfigMap       dso202-dev  frontend-config         Synced                  
       Service         dso202-dev  frontend                Synced  Healthy         
apps   Deployment      dso202-dev  frontend                Synced  Healthy         
batch  Job             dso202-dev  tasktracker-smoke-test          Healthy         

$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Degraded
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Degraded
tasktracker-staging   Synced        Healthy

$ kubectl get deploy backend -n dso202-dev -o jsonpath='{range .status.conditions[*]}...{end}'
Available=True MinimumReplicasAvailable: Deployment has minimum availability.
Progressing=False ProgressDeadlineExceeded: ReplicaSet "backend-664d47bfd" has timed out progressing.

$ kubectl get jobs -n dso202-dev
NAME                     STATUS     COMPLETIONS   DURATION   AGE
tasktracker-smoke-test   Complete   1/1           4s         14m

$ curl -s -o /dev/null -w "frontend HTTP %{http_code}\n" http://localhost:30080/
frontend HTTP 200
```

Observations for dev:

- **New backend Pod:** started at 22:44:32 and exited with code 1 within two seconds. It went into `CrashLoopBackOff` and restarted with growing back-off delays. It never became ready.
- **Old backend Pod:** stayed `1/1 Running` and kept serving. A rolling update removes an old Pod only after a new one is ready, so the API stayed up on `1.0`.
- **Application:** went `Synced / Progressing` at 22:44:33, then `Synced / Degraded` at 22:46:33, 120 s after the rollout began (C6). The Deployment message was `Deployment "backend" exceeded its progress deadline`. Sync status stayed `Synced`: the live Deployment matched Git exactly, but it did not work (see Q3). `root` followed, to `Degraded`.
- **Smoke test:** did not run again. The only Job was the one completed 14 minutes earlier for PR #1. A PostSync hook runs only after every synced resource is healthy, and the sync operation stayed in `Running` with "Retrying operation" instead.
- **Frontend:** still answered HTTP 200 at `http://localhost:30080`.
- **Staging:** stayed `Synced / Healthy` throughout, on `v1.1.0`.

### Part B, step 6: diagnosis

```text
$ kubectl describe pod backend-664d47bfd-827vg -n dso202-dev      (Containers section and Events)
Name:             backend-664d47bfd-827vg
Namespace:        dso202-dev
Node:             dso202-gitops-control-plane/172.18.0.2
Status:           Running
Controlled By:  ReplicaSet/backend-664d47bfd
Containers:
  backend:
    Container ID:   containerd://affb85c8998046991c51e8fadcbd25acaeb44e25858adcd7e9726e07953d1032
    Image:          dso202-local/dso202-backend:1.1
    Image ID:       sha256:019a68277904cc0a068d152808fa899467a9bce960fb0fd9196f247f795206a5
    Port:           8080/TCP (http)
    Host Port:      0/TCP (http)
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Fri, 27 Nov 2026 22:46:09 +0600
      Finished:     Fri, 27 Nov 2026 22:46:09 +0600
    Ready:          False
    Restart Count:  4
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:      100m
      memory:   128Mi
    Readiness:  http-get http://:http/api/status delay=0s timeout=1s period=5s #success=1 #failure=3
    Environment Variables from:
      backend-config  ConfigMap  Optional: false
    Environment:
      DB_USER:      <set to the key 'DB_USER' in secret 'tasktracker-credentials'>      Optional: false
      DB_PASSWORD:  <set to the key 'DB_PASSWORD' in secret 'tasktracker-credentials'>  Optional: false
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-8gn4t (ro)
...
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  2m21s                default-scheduler  Successfully assigned dso202-dev/backend-664d47bfd-827vg to dso202-gitops-control-plane
  Normal   Pulled     45s (x5 over 2m21s)  kubelet            spec.containers{backend}: Container image "dso202-local/dso202-backend:1.1" already present on machine and can be accessed by the pod
  Normal   Created    45s (x5 over 2m21s)  kubelet            spec.containers{backend}: Container created
  Normal   Started    45s (x5 over 2m21s)  kubelet            spec.containers{backend}: Container started
  Warning  Unhealthy  45s (x5 over 2m21s)  kubelet            spec.containers{backend}: Readiness probe failed: Get "http://10.244.0.23:8080/api/status": dial tcp 10.244.0.23:8080: connect: connection refused
  Warning  BackOff    43s (x8 over 2m19s)  kubelet            spec.containers{backend}: Back-off restarting failed container backend in pod backend-664d47bfd-827vg_dso202-dev(fb5a4839-8b6d-4cf5-b393-39ea1f230a40)

$ kubectl logs backend-664d47bfd-827vg -n dso202-dev
[config] FATAL: required environment variable DB_POOL_MAX is not set (maximum number of database connections, a positive integer such as "10")
```

The log line that states what the new image requires:

```text
[config] FATAL: required environment variable DB_POOL_MAX is not set (maximum number of database connections, a positive integer such as "10")
```

`describe` shows only the symptoms: `Exit Code: 1`, `Restart Count`, `BackOff`, and readiness probe failures with "connection refused", because the process never opened its port. The image was present and the Pod was scheduled, so this is not a pull or scheduling problem. The cause is in the logs: the release note promised only "internal refactoring", but the new image needs a setting that the `1.0` image did not.

### Part B, step 7: `argocd app rollback`

```text
$ argocd app rollback tasktracker-dev
{"level":"fatal","msg":"rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled","time":"2026-11-27T22:46:54+06:00"}
exit code: 20
```

Argo CD refuses with `FailedPrecondition: rollback cannot be initiated when auto-sync is enabled`, and the CLI exits with code 20. See Q5.

### Part B, step 8: recovery through `git revert`

```text
$ git checkout -b revert/backend-1.1
$ git revert --no-edit -m 1 0a3267f
[revert/backend-1.1 e8342ec] Revert "Merge pull request #3 from Kinley-pal8/release/backend-1.1"
 2 files changed, 2 insertions(+), 6 deletions(-)
$ git push -u origin revert/backend-1.1
# pull request #4, merged as 91ce0d7
```

Recovery took about four minutes after the merge, not one, and the reason is worth recording. The Application has a retry policy: `limit: 5`, back-off from 10 s doubling to a 3 min cap. The failed sync of `0a3267f` was still `Running`, retrying. Auto-sync does not start a new operation while one is in progress, so dev stayed `OutOfSync / Degraded` on the reverted commit until the retry loop came round again. Its fifth attempt picked up the new revision. Operation state, polled every 5 s (repeated lines removed):

```text
22:51:14 OutOfSync/Degraded op=Running rev=0a3267f3e97b0bb3dd6d2c94ed300309260b1dc0 msg=one or more synchronization tasks completed unsuccessfully. Retrying attempt #4 at 4:50PM.
22:51:49 OutOfSync/Degraded op=Running rev=0a3267f3e97b0bb3dd6d2c94ed300309260b1dc0 msg=waiting for healthy state of /ConfigMap/db-config and 2 more resources
22:51:54 OutOfSync/Degraded op=Running rev=0a3267f3e97b0bb3dd6d2c94ed300309260b1dc0 msg=one or more synchronization tasks completed unsuccessfully. Retrying attempt #5 at 4:54PM.
22:54:51 OutOfSync/Degraded op=Running rev=0a3267f3e97b0bb3dd6d2c94ed300309260b1dc0 msg=Retrying operation. Attempt #5
22:54:56 OutOfSync/Degraded op=Running rev=91ce0d7bb626eb07732dc47c8b640c9bce3da07b msg=
22:55:01 Synced/Healthy op=Running rev=91ce0d7bb626eb07732dc47c8b640c9bce3da07b msg=waiting for healthy state of /ServiceAccount/backend-sa and 3 more resources
```

```text
$ kubectl get pods -n dso202-dev
NAME                           READY   STATUS      RESTARTS      AGE
backend-d666f4fd-j5ltm         1/1     Running     2 (49m ago)   2d21h
db-0                           1/1     Running     2 (49m ago)   2d21h
frontend-698c7d47fb-wc8cf      1/1     Running     0             23m
tasktracker-smoke-test-r8jrk   0/1     Completed   0             25s

$ kubectl get deploy backend -n dso202-dev -o jsonpath='{..image}'
sarojsanyasi/dso202-backend:1.0

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
Sync Status:        Synced to main (91ce0d7)
Health Status:      Healthy
GROUP  KIND            NAMESPACE   NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-dev  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-dev  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-dev  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7cb8df4897...
       ServiceAccount  dso202-dev  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-dev  backend-config          Synced                        configmap/backend-config unchanged
       Service         dso202-dev  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-dev  backend                 Synced     Healthy            deployment.apps/backend configured
       ConfigMap       dso202-dev  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-dev  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-dev  frontend                Synced     Healthy            deployment.apps/frontend unchanged
batch  Job             dso202-dev  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ argocd app history tasktracker-dev
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:29:39 +0600 +06  main (86bd5bb)
1       2026-11-27 22:31:54 +0600 +06  main (3c1879a)
2       2026-11-27 22:55:06 +0600 +06  main (91ce0d7)
```

Dev is `Healthy` again on the baseline backend `1.0`. The crash-looping Pod was removed, and the smoke test passed. The Git history now holds both the bad commit `0a3267f` and its revert `91ce0d7`. `argocd app history` has no entry for `0a3267f`, because that sync never succeeded.

An alternative to waiting was `argocd app terminate-op tasktracker-dev`, which ends the stuck operation so that auto-sync picks up the revert at once. I did not use it, so that the default behaviour could be observed.

### Part B, step 9: fix forward

Pull request #5 sets the backend to `1.1` again and supplies what the log required, as a value (C2). The chart merges `backend.config` into the `backend-config` ConfigMap, which the Deployment reads through `envFrom`. The ConfigMap checksum annotation changes with it, so the Pods roll. No template changed.

```text
$ git diff 91ce0d7 95717b8 -- environments/dev/values.yaml
diff --git a/environments/dev/values.yaml b/environments/dev/values.yaml
index d82b8f9..15083be 100644
--- a/environments/dev/values.yaml
+++ b/environments/dev/values.yaml
@@ -20,7 +20,14 @@ database:
 backend:
   replicaCount: 1
   image:
-    tag: "1.0"
+    # Stand-in 1.1 image built from stand-in-images/backend (tutor-approved).
+    repository: dso202-local/dso202-backend
+    tag: "1.1"
+  # C2: backend 1.1 exits at start-up without DB_POOL_MAX (Task 7, step 6:
+  # "[config] FATAL: required environment variable DB_POOL_MAX is not set").
+  # Merged into the chart's backend.config and rendered into backend-config.
+  config:
+    DB_POOL_MAX: "10"
 
 frontend:
   replicaCount: 1
```

```text
$ kubectl get pods -n dso202-dev        # 15 s after the sync
NAME                           READY   STATUS        RESTARTS      AGE
backend-7db9c4769-zn5pz        1/1     Running       0             16s
backend-d666f4fd-j5ltm         1/1     Terminating   2 (53m ago)   2d21h
db-0                           1/1     Running       2 (53m ago)   2d21h
frontend-698c7d47fb-wc8cf      1/1     Running       0             28m
tasktracker-smoke-test-55w5v   0/1     Completed     0             12s

$ kubectl logs backend-7db9c4769-zn5pz -n dso202-dev
[config] loaded: db db:5432/taskdb, pool max 10
[db] connected
[server] listening on :8080

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
Sync Status:        Synced to main (95717b8)
Health Status:      Healthy
GROUP  KIND            NAMESPACE   NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-dev  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-dev  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-dev  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7cb8df4897...
       ServiceAccount  dso202-dev  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-dev  backend-config          Synced                        configmap/backend-config configured
       Service         dso202-dev  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-dev  backend                 Synced     Healthy            deployment.apps/backend configured
       ConfigMap       dso202-dev  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-dev  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-dev  frontend                Synced     Healthy            deployment.apps/frontend unchanged
batch  Job             dso202-dev  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ argocd app history tasktracker-dev
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:29:39 +0600 +06  main (86bd5bb)
1       2026-11-27 22:31:54 +0600 +06  main (3c1879a)
2       2026-11-27 22:55:06 +0600 +06  main (91ce0d7)
3       2026-11-27 22:59:49 +0600 +06  main (95717b8)

$ kubectl run curl-check --rm -i --restart=Never -n dso202-dev --image=busybox:1.37 -- wget -qO- http://backend:8080/api/status
{"status":"ok","db":"connected"}
```

Dev is `Synced / Healthy` on `95717b8`, running `dso202-local/dso202-backend:1.1`. The backend logs `pool max 10`, connects to the database and serves the API, and the PostSync smoke test passed.

### Part B, step 10: promotion of the fixed release to staging

```text
$ git tag -a v1.2.0 -m "Release: backend 1.1 with DB_POOL_MAX"     # on 95717b8
$ git push origin v1.2.0
# then pull request #6 (targetRevision: v1.2.0), merged as 08e5e1b
```

```text
$ argocd app get tasktracker-staging     # before the sync
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.2.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from v1.2.0 (95717b8)
Health Status:      Healthy
GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-staging  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-staging  backend-config          OutOfSync                     configmap/backend-config unchanged
       Service         dso202-staging  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-staging  backend                 OutOfSync  Healthy            deployment.apps/backend unchanged
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend configured
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ kubectl get deploy backend -n dso202-staging -o jsonpath='{..image}'
sarojsanyasi/dso202-backend:1.0

$ argocd app sync tasktracker-staging
TIMESTAMP                  GROUP        KIND       NAMESPACE                      NAME      STATUS    HEALTH        HOOK  MESSAGE
2026-11-27T23:27:57+06:00   apps  StatefulSet     dso202-staging                    db      Synced   Healthy              
2026-11-27T23:27:57+06:00  batch         Job      dso202-staging  tasktracker-smoke-test             Healthy              
2026-11-27T23:27:57+06:00          ConfigMap      dso202-staging        backend-config    OutOfSync                       
2026-11-27T23:27:57+06:00          ConfigMap      dso202-staging             db-config      Synced                        
2026-11-27T23:27:57+06:00          ConfigMap      dso202-staging       frontend-config      Synced                        
2026-11-27T23:27:57+06:00            Service      dso202-staging               backend      Synced   Healthy              
2026-11-27T23:27:57+06:00            Service      dso202-staging                    db      Synced   Healthy              
2026-11-27T23:27:57+06:00            Service      dso202-staging              frontend      Synced   Healthy              
2026-11-27T23:27:57+06:00         ServiceAccount  dso202-staging            backend-sa      Synced                        
2026-11-27T23:27:57+06:00   apps  Deployment      dso202-staging               backend    OutOfSync  Healthy              
2026-11-27T23:27:57+06:00   apps  Deployment      dso202-staging              frontend      Synced   Healthy              
2026-11-27T23:28:00+06:00   apps  StatefulSet  dso202-staging                    db    Synced  Healthy              statefulset.apps/db configured
2026-11-27T23:28:00+06:00          ConfigMap   dso202-staging             db-config    Synced                       configmap/db-config unchanged
2026-11-27T23:28:00+06:00            Service   dso202-staging                    db    Synced  Healthy              service/db unchanged
2026-11-27T23:28:00+06:00          ConfigMap  dso202-staging        backend-config    Synced                       
2026-11-27T23:28:00+06:00   apps  Deployment  dso202-staging               backend    Synced  Progressing              
2026-11-27T23:28:02+06:00   apps  Deployment  dso202-staging               backend    Synced  Healthy              
2026-11-27T23:28:02+06:00   apps  Deployment      dso202-staging               backend    Synced  Healthy              deployment.apps/backend configured
2026-11-27T23:28:02+06:00   apps  StatefulSet     dso202-staging                    db    Synced  Healthy              statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
2026-11-27T23:28:02+06:00         ServiceAccount  dso202-staging            backend-sa    Synced                       serviceaccount/backend-sa unchanged
2026-11-27T23:28:02+06:00          ConfigMap      dso202-staging        backend-config    Synced                       configmap/backend-config configured
2026-11-27T23:28:02+06:00            Service      dso202-staging               backend    Synced  Healthy              service/backend unchanged
2026-11-27T23:28:04+06:00   apps  Deployment  dso202-staging              frontend    Synced  Healthy              deployment.apps/frontend unchanged
2026-11-27T23:28:04+06:00          ConfigMap  dso202-staging       frontend-config    Synced                       configmap/frontend-config unchanged
2026-11-27T23:28:04+06:00            Service  dso202-staging              frontend    Synced  Healthy              service/frontend unchanged
2026-11-27T23:28:04+06:00  batch         Job  dso202-staging  tasktracker-smoke-test   Running   Synced    PostSync  job.batch/tasktracker-smoke-test created
2026-11-27T23:28:09+06:00  batch         Job  dso202-staging  tasktracker-smoke-test  Succeeded   Synced    PostSync  Reached expected number of succeeded pods
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kinley-pal8/dso202-gitops.git
  Target:           v1.2.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        Synced to v1.2.0 (95717b8)
Health Status:      Healthy
Operation:          Sync
Sync Revision:      95717b8d7d238816c3cb70922ae8fc5a86feef3e
Phase:              Succeeded
Start:              2026-11-27 23:27:57 +0600 +06
Finished:           2026-11-27 23:28:09 +0600 +06
Duration:           12s
Message:            successfully synced (no more tasks)
GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-staging  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config configured
       Service         dso202-staging  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend configured
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend unchanged
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods
```

```text
$ kubectl get pods -n dso202-staging    # just after the sync
NAME                           READY   STATUS        RESTARTS      AGE
backend-586d6f8bb7-bxmkh       1/1     Running       0             10s
backend-756c85f6cb-jqkjw       1/1     Terminating   2 (81m ago)   2d21h
db-0                           1/1     Running       2 (81m ago)   2d21h
frontend-68b7c88f4b-q6krm      1/1     Running       0             47m
tasktracker-smoke-test-qd55d   0/1     Completed     0             6s

$ kubectl logs backend-586d6f8bb7-bxmkh -n dso202-staging
[config] loaded: db db:5432/taskdb, pool max 10
[db] connected
[server] listening on :8080

$ argocd app history tasktracker-staging
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:30:41 +0600 +06  v1.0.0 (10e828a)
1       2026-11-27 22:40:42 +0600 +06  v1.1.0 (3c1879a)
2       2026-11-27 23:28:09 +0600 +06  v1.2.0 (95717b8)

$ argocd app history tasktracker-dev
SOURCE  https://github.com/Kinley-pal8/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-25 01:29:39 +0600 +06  main (86bd5bb)
1       2026-11-27 22:31:54 +0600 +06  main (3c1879a)
2       2026-11-27 22:55:06 +0600 +06  main (91ce0d7)
3       2026-11-27 22:59:49 +0600 +06  main (95717b8)

$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Healthy
tasktracker-staging   Synced        Healthy
### kubectl logs backend-586d6f8bb7-bxmkh -n dso202-staging
[config] loaded: db db:5432/taskdb, pool max 10
[db] connected
[server] listening on :8080
```

Staging went from `v1.1.0` straight to `v1.2.0`: backend `1.0` to `1.1` with `DB_POOL_MAX`, healthy, with a passing smoke test. Its history is `v1.0.0` (`10e828a`), `v1.1.0` (`3c1879a`) and `v1.2.0` (`95717b8`). The faulty revision `0a3267f` never appears, so **staging never ran the faulty backend**. The gate worked: staging only ever receives a tag that dev has already proven.

All six Applications ended `Synced / Healthy`.

---

## Task 8: Drift, Pruning and Project Guardrails

All four predictions were written to a file before any drill command was run (2026-11-27 23:35:28 +0600). They are reproduced unchanged at the start of each drill.

### Drill 1: drift in dev is reverted

**Prediction.** Self-heal reverts it. The Deployment returns to 1 replica within a few seconds. The two extra Pods start and are then terminated, and tasktracker-dev ends Synced/Healthy without anyone syncing.

The watches were started 3 s before the change.

```text
$ kubectl get deployment -n dso202-dev
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
backend    1/1     1            1           2d22h
frontend   1/1     1            1           2d22h
$ kubectl scale deployment/backend -n dso202-dev --replicas=3    # at 23:35:38
deployment.apps/backend scaled

$ kubectl get deployment/backend -n dso202-dev -w    (local time)
23:35:35 NAME      READY   UP-TO-DATE   AVAILABLE   AGE
23:35:35 backend   1/1     1            1           2d22h
23:35:38 backend   1/3     1            1           2d22h
23:35:38 backend   1/3     1            1           2d22h
23:35:38 backend   1/3     1            1           2d22h
23:35:38 backend   1/3     3            1           2d22h
23:35:38 backend   1/1     3            1           2d22h
23:35:38 backend   1/1     3            1           2d22h
23:35:38 backend   1/1     3            1           2d22h
23:35:39 backend   1/1     1            1           2d22h
23:36:09 backend   1/1     1            1           2d22h
23:36:09 backend   1/1     1            1           2d22h

$ kubectl get pods -n dso202-dev -l tier=backend -w    (local time)
23:35:35 NAME                      READY   STATUS    RESTARTS   AGE
23:35:35 backend-7db9c4769-zn5pz   1/1     Running   0          35m
23:35:38 backend-7db9c4769-hwcg9   0/1     Pending   0          0s
23:35:38 backend-7db9c4769-hwcg9   0/1     Pending   0          0s
23:35:38 backend-7db9c4769-xldl5   0/1     Pending   0          0s
23:35:38 backend-7db9c4769-xldl5   0/1     Pending   0          0s
23:35:38 backend-7db9c4769-hwcg9   0/1     ContainerCreating   0          0s
23:35:38 backend-7db9c4769-xldl5   0/1     ContainerCreating   0          0s
23:35:38 backend-7db9c4769-xldl5   0/1     Terminating         0          0s
23:35:38 backend-7db9c4769-hwcg9   0/1     Terminating         0          0s
23:35:39 backend-7db9c4769-xldl5   0/1     Terminating         0          1s
23:35:39 backend-7db9c4769-hwcg9   0/1     Terminating         0          1s
23:35:39 backend-7db9c4769-xldl5   0/1     Terminating         0          1s
23:35:39 backend-7db9c4769-hwcg9   0/1     Terminating         0          1s
23:35:44 backend-7db9c4769-xldl5   1/1     Terminating         0          6s
23:35:44 backend-7db9c4769-hwcg9   1/1     Terminating         0          6s
23:36:09 backend-7db9c4769-hwcg9   0/1     Error               0          31s
23:36:09 backend-7db9c4769-xldl5   0/1     Error               0          31s
23:36:09 backend-7db9c4769-hwcg9   0/1     Error               0          31s
23:36:09 backend-7db9c4769-xldl5   0/1     Error               0          31s
23:36:09 backend-7db9c4769-xldl5   0/1     Error               0          31s
23:36:09 backend-7db9c4769-xldl5   0/1     Error               0          31s
23:36:09 backend-7db9c4769-hwcg9   0/1     Error               0          31s
23:36:09 backend-7db9c4769-hwcg9   0/1     Error               0          31s

$ argocd app get tasktracker-dev    # at 23:36:22
Sync Status:        Synced to main (2df4627)
Health Status:      Healthy
apps   Deployment      dso202-dev  backend                 Synced  Healthy        deployment.apps/backend configured
apps   Deployment      dso202-dev  frontend                Synced  Healthy        

$ kubectl get events -n dso202-dev --field-selector involvedObject.name=backend --sort-by=.lastTimestamp | tail -4
36m         Normal   ScalingReplicaSet   deployment/backend   Scaled up replica set backend-7db9c4769 from 0 to 1
36m         Normal   ScalingReplicaSet   deployment/backend   Scaled down replica set backend-d666f4fd from 1 to 0
44s         Normal   ScalingReplicaSet   deployment/backend   Scaled up replica set backend-7db9c4769 from 1 to 3
44s         Normal   ScalingReplicaSet   deployment/backend   Scaled down replica set backend-7db9c4769 from 3 to 1
```

**Observation.** `kubectl scale` set the replicas to 3 at 23:35:38. In the same second, the Deployment went back to `1/1` and the ReplicaSet was "Scaled down ... from 3 to 1". The two new Pods were sent to `Terminating` before they finished `ContainerCreating`, and the Application stayed `Synced / Healthy`. The extra Pods took about 30 s to disappear and ended in `Error`. That is the termination grace period: the Node.js process does not handle SIGTERM, so the kubelet killed it after the 30 s grace period. It is not a second failure.

**Prediction held.** The reversion was faster than predicted, under one second. `selfHeal: true` in `tasktracker-dev` makes the controller treat any difference from Git as drift and re-apply Git at once. Its watch on the Deployment fires immediately, so no 60 s poll is involved (principle 4: continuously reconciled).

### Drill 2: drift in staging is reported, not reverted

**Prediction.** Nothing reverts it. Staging has no automated sync, so all 3 replicas keep running. tasktracker-staging reports OutOfSync, and argocd app diff shows replicas 1 (Git) against 3 (live). Only a manual sync brings it back to 1.

```text
$ kubectl scale deployment/backend -n dso202-staging --replicas=3    # at 23:36:32
deployment.apps/backend scaled

$ kubectl get deployment/backend -n dso202-staging -w    (local time, 40 s)
23:36:30 NAME      READY   UP-TO-DATE   AVAILABLE   AGE
23:36:30 backend   1/1     1            1           2d22h
23:36:32 backend   1/3     1            1           2d22h
23:36:32 backend   1/3     1            1           2d22h
23:36:32 backend   1/3     1            1           2d22h
23:36:32 backend   1/3     3            1           2d22h
23:36:38 backend   2/3     3            2           2d22h
23:36:38 backend   3/3     3            3           2d22h

$ kubectl get pods -n dso202-staging -l tier=backend    # at 23:37:12
NAME                       READY   STATUS    RESTARTS   AGE
backend-586d6f8bb7-4ltvg   1/1     Running   0          40s
backend-586d6f8bb7-bxmkh   1/1     Running   0          9m12s
backend-586d6f8bb7-qwr2b   1/1     Running   0          40s

$ argocd app get tasktracker-staging --refresh
Namespace:          dso202-staging
  Target:           v1.2.0
  Helm Values:      ../../environments/staging/values.yaml
Sync Policy:        Manual
Sync Status:        OutOfSync from v1.2.0 (95717b8)
Health Status:      Healthy

GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-staging  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config configured
       Service         dso202-staging  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-staging  backend                 OutOfSync  Healthy            deployment.apps/backend configured
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend unchanged
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ argocd app diff tasktracker-staging

===== apps/Deployment dso202-staging/backend ======
176c176
<   replicas: 3
---
>   replicas: 1
(exit code 1)

$ argocd app sync tasktracker-staging    # at 23:37:13
TIMESTAMP                  GROUP        KIND       NAMESPACE                      NAME      STATUS    HEALTH        HOOK  MESSAGE
2026-11-27T23:37:14+06:00          ConfigMap      dso202-staging        backend-config      Synced                        
2026-11-27T23:37:14+06:00            Service      dso202-staging               backend      Synced   Healthy              
2026-11-27T23:37:14+06:00            Service      dso202-staging                    db      Synced   Healthy              
2026-11-27T23:37:14+06:00   apps  Deployment      dso202-staging               backend    OutOfSync  Healthy              
2026-11-27T23:37:14+06:00   apps  StatefulSet     dso202-staging                    db      Synced   Healthy              
2026-11-27T23:37:14+06:00  batch         Job      dso202-staging  tasktracker-smoke-test             Healthy              
2026-11-27T23:37:14+06:00          ConfigMap      dso202-staging             db-config      Synced                        
2026-11-27T23:37:14+06:00          ConfigMap      dso202-staging       frontend-config      Synced                        
2026-11-27T23:37:14+06:00            Service      dso202-staging              frontend      Synced   Healthy              
2026-11-27T23:37:14+06:00         ServiceAccount  dso202-staging            backend-sa      Synced                        
2026-11-27T23:37:14+06:00   apps  Deployment      dso202-staging              frontend      Synced   Healthy              
2026-11-27T23:37:17+06:00   apps  StatefulSet  dso202-staging                    db    Synced  Healthy              statefulset.apps/db configured
2026-11-27T23:37:17+06:00          ConfigMap   dso202-staging             db-config    Synced                       configmap/db-config unchanged
2026-11-27T23:37:17+06:00            Service   dso202-staging                    db    Synced  Healthy              service/db unchanged
2026-11-27T23:37:17+06:00   apps  Deployment  dso202-staging               backend    Synced  Healthy              
2026-11-27T23:37:19+06:00          ConfigMap      dso202-staging        backend-config    Synced                       configmap/backend-config unchanged
2026-11-27T23:37:19+06:00            Service      dso202-staging               backend    Synced  Healthy              service/backend unchanged
2026-11-27T23:37:19+06:00   apps  Deployment      dso202-staging               backend    Synced  Healthy              deployment.apps/backend configured
2026-11-27T23:37:19+06:00   apps  StatefulSet     dso202-staging                    db    Synced  Healthy              statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
2026-11-27T23:37:19+06:00         ServiceAccount  dso202-staging            backend-sa    Synced                       serviceaccount/backend-sa unchanged
2026-11-27T23:37:21+06:00          ConfigMap  dso202-staging       frontend-config    Synced                       configmap/frontend-config unchanged
2026-11-27T23:37:21+06:00            Service  dso202-staging              frontend    Synced  Healthy              service/frontend unchanged
2026-11-27T23:37:21+06:00   apps  Deployment  dso202-staging              frontend    Synced  Healthy              deployment.apps/frontend unchanged
2026-11-27T23:37:21+06:00  batch         Job  dso202-staging  tasktracker-smoke-test   Running   Synced    PostSync  job.batch/tasktracker-smoke-test created
2026-11-27T23:37:26+06:00  batch         Job  dso202-staging  tasktracker-smoke-test  Succeeded   Synced    PostSync  Reached expected number of succeeded pods

Namespace:          dso202-staging
  Target:           v1.2.0
  Helm Values:      ../../environments/staging/values.yaml
Sync Policy:        Manual
Sync Status:        Synced to v1.2.0 (95717b8)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      95717b8d7d238816c3cb70922ae8fc5a86feef3e
Phase:              Succeeded
Start:              2026-11-27 23:37:14 +0600 +06
Finished:           2026-11-27 23:37:26 +0600 +06
Duration:           12s
Message:            successfully synced (no more tasks)

GROUP  KIND            NAMESPACE       NAME                    STATUS     HEALTH   HOOK      MESSAGE
       ConfigMap       dso202-staging  db-config               Synced                        configmap/db-config unchanged
       Service         dso202-staging  db                      Synced     Healthy            service/db unchanged
apps   StatefulSet     dso202-staging  db                      Synced     Healthy            statefulset rolling update complete 1 pods at revision db-7c88c9db6c...
       ServiceAccount  dso202-staging  backend-sa              Synced                        serviceaccount/backend-sa unchanged
       ConfigMap       dso202-staging  backend-config          Synced                        configmap/backend-config unchanged
       Service         dso202-staging  backend                 Synced     Healthy            service/backend unchanged
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend configured
       ConfigMap       dso202-staging  frontend-config         Synced                        configmap/frontend-config unchanged
       Service         dso202-staging  frontend                Synced     Healthy            service/frontend unchanged
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend unchanged
batch  Job             dso202-staging  tasktracker-smoke-test  Succeeded  Synced   PostSync  Reached expected number of succeeded pods

$ kubectl get deployment/backend -n dso202-staging    # at 23:38:04
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
backend   1/1     1            1           2d22h

$ argocd app get tasktracker-staging
Sync Status:        Synced to v1.2.0 (95717b8)
Health Status:      Healthy
apps   Deployment      dso202-staging  backend                 Synced     Healthy            deployment.apps/backend configured
apps   Deployment      dso202-staging  frontend                Synced     Healthy            deployment.apps/frontend unchanged
```

**Observation.** All three replicas became ready and stayed for 40 s, untouched. Argo CD reported only the backend Deployment as `OutOfSync`, and `argocd app diff` showed exactly one difference, `replicas: 3` live against `replicas: 1` from tag `v1.2.0`. The manual sync restored one replica and ran the smoke test.

**Prediction held.** `tasktracker-staging` has no `automated` block, so Argo CD still detects drift but only reports it. A person decides when Git is re-applied, the same gate that keeps unproven releases out of staging.

### Drill 3: removing a file prunes the object

**Prediction.** After the first push, platform-dev creates ConfigMap prune-drill in dso202-dev within about a minute. After the removal, it is deleted again, because platform-dev has prune: true.

Listing 16 was saved as `platform/dev/prune-drill.yaml`. Its last line is cut off in the PDF; it was completed as `"... expected to disappear from the cluster by pruning."`.

```text
pushed 44a3d06 at 23:38:15
$ kubectl get configmap prune-drill -n dso202-dev    # at 23:38:36
NAME          DATA   AGE
prune-drill   1      2s

$ git rm platform/dev/prune-drill.yaml && git commit && git push
pushed 2f00555 at 23:38:45

$ kubectl get configmap prune-drill -n dso202-dev    # at 23:40:36
Error from server (NotFound): configmaps "prune-drill" not found

$ kubectl get configmap -n dso202-dev -w --output-watch-events    (local time, prune-drill only)
23:38:13 EVENT      NAME               DATA   AGE
23:38:34 ADDED      prune-drill        1      0s
23:40:32 MODIFIED   prune-drill        1      118s
23:40:32 DELETED    prune-drill        1      118s

$ argocd app get platform-dev
Sync Status:        Synced to main (2f00555)
Health Status:      Healthy
                           ConfigMap       dso202-dev  prune-drill                Succeeded  Pruned         pruned
                           Namespace       dso202-dev  dso202-dev                 Running    Synced         namespace/dso202-dev unchanged
                           Namespace                   dso202-dev                 Synced                    

$ argocd app history platform-dev | tail -3
0       2026-11-25 01:21:53 +0600 +06  main (846ae44)
1       2026-11-27 23:38:34 +0600 +06  main (44a3d06)
2       2026-11-27 23:40:32 +0600 +06  main (2f00555)
```

**Observation.** The ConfigMap was created 19 s after the push of `44a3d06`. After `git rm` was pushed (`2f00555`, 23:38:45), it was deleted at 23:40:32, about 1 min 47 s later. Argo CD found the change on its next poll of the repository (`timeout.reconciliation: 60s` in `argocd-cm`, plus up to 60 s of jitter), and `platform-dev` listed it as `Pruned`.

**Prediction held,** although the deletion took longer than "about a minute" because of the polling interval. `prune: true` in `platform-dev` lets the controller delete live objects that it manages and that no longer exist in Git. Without it, the ConfigMap would stay and only be reported as `OutOfSync` ("requires pruning").

**Why the namespace is protected (explained, not tested).** `platform/dev/namespace.yaml` (Listing 11) carries `argocd.argoproj.io/sync-options: Prune=false`. If that file were deleted from Git, `platform-dev` would show the Namespace as `OutOfSync` but would never delete it. Deleting a Namespace deletes everything inside it: the workloads, the Secret, and the database PVC with its data. That should never happen as a side effect of a file removal, so it requires a deliberate `kubectl delete namespace` by a person.

### Drill 4: the project rejects a resource it does not permit

**Prediction.** `tasktracker-dev` refuses to sync. Its status shows that the ResourceQuota kind is not permitted in project dso202, and nothing is created. Staging is unaffected because it reads tag v1.2.0, which does not contain the file. Reverting the commit returns dev to Synced/Healthy.

Listing 17 was saved as `charts/tasktracker/templates/drill-quota.yaml`, committed and pushed to `main`.

```text
pushed b8c4b79 at 23:40:47

$ argocd app get tasktracker-dev    # at 23:42:56
Namespace:          dso202-dev
  Target:           main
  Helm Values:      ../../environments/dev/values.yaml
Sync Policy:        Automated (Prune)
Sync Status:        OutOfSync from main (b8c4b79)
Health Status:      Healthy

GROUP  KIND            NAMESPACE   NAME                    STATUS   HEALTH   HOOK  MESSAGE
       ResourceQuota   dso202-dev  drill-quota             Unknown  Missing        resource :ResourceQuota is not permitted in project dso202
       ConfigMap       dso202-dev  backend-config          Synced                  
       ConfigMap       dso202-dev  db-config               Synced                  
       ConfigMap       dso202-dev  frontend-config         Synced                  
       Service         dso202-dev  backend                 Synced   Healthy        
       Service         dso202-dev  db                      Synced   Healthy        
       Service         dso202-dev  frontend                Synced   Healthy        
       ServiceAccount  dso202-dev  backend-sa              Synced                  
apps   Deployment      dso202-dev  backend                 Synced   Healthy        
apps   Deployment      dso202-dev  frontend                Synced   Healthy        
apps   StatefulSet     dso202-dev  db                      Synced   Healthy        
batch  Job             dso202-dev  tasktracker-smoke-test           Healthy        

$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       OutOfSync     Healthy
tasktracker-staging   Synced        Healthy

$ kubectl get resourcequota -n dso202-dev
NAME                 REQUEST                                                                                     LIMIT                                           AGE
task-tracker-quota   persistentvolumeclaims: 1/2, pods: 3/20, requests.cpu: 250m/1, requests.memory: 384Mi/1Gi   limits.cpu: 1200m/3, limits.memory: 896Mi/2Gi   2d22h

$ argocd app get tasktracker-staging
  Target:           v1.2.0
Sync Status:        Synced to v1.2.0 (95717b8)
Health Status:      Healthy

$ git ls-tree -r --name-only v1.2.0 charts/tasktracker/templates/ | grep drill
(no output: the file is not in tag v1.2.0)

$ git revert --no-edit b8c4b79
[main 746b787] Revert "Task 8 drill 4: add ResourceQuota to the chart (Listing 17; expect rejection)"
 Date: Fri Nov 27 23:43:04 2026 +0600
 1 file changed, 15 deletions(-)
 delete mode 100644 charts/tasktracker/templates/drill-quota.yaml
pushed 746b787 at 23:43:06

$ argocd app get tasktracker-dev    # at 23:48:12
Sync Status:        Synced to main (746b787)
Health Status:      Healthy
       ResourceQuota   dso202-dev  drill-quota                     SyncFailed        resource :ResourceQuota is not permitted in project dso202
apps   Deployment      dso202-dev  backend                 Synced  Healthy           
apps   Deployment      dso202-dev  frontend                Synced  Healthy           

$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Healthy
tasktracker-staging   Synced        Healthy

# operation state at 23:48:53, after the retry loop ended
phase=Failed revision=b8c4b798cad5aa7411304f39a60ea8045a758ef5 message=one or more synchronization tasks are not valid: resource :ResourceQuota is not permitted in project dso202 (retried 5 times).

$ argocd app get tasktracker-dev
Sync Status:        Synced to main (746b787)
Health Status:      Healthy
       ResourceQuota   dso202-dev  drill-quota                     SyncFailed        resource :ResourceQuota is not permitted in project dso202
apps   Deployment      dso202-dev  backend                 Synced  Healthy           
apps   Deployment      dso202-dev  frontend                Synced  Healthy           
batch  Job             dso202-dev  tasktracker-smoke-test          Healthy           
```

The exact message:

```text
one or more synchronization tasks are not valid: resource :ResourceQuota is not permitted in project dso202
```

**Observation.** `tasktracker-dev` went `OutOfSync` and refused the whole sync operation, not only the ResourceQuota. Argo CD validates every resource against the project before applying any of them, so no `drill-quota` was created; the only quota in `dso202-dev` is the platform's `task-tracker-quota`. The running workload stayed `Healthy`. The automated sync retried with back-off and finally ended `Failed ... (retried 5 times)`.

**Staging was unaffected.** `tasktracker-staging` stayed `Synced / Healthy` on `v1.2.0`. It reads the chart from tag `v1.2.0`, which points at commit `95717b8`, and that commit does not contain the template (`git ls-tree` prints nothing). A commit to `main` cannot reach staging until a person moves its `targetRevision`.

**Restore.** `git revert b8c4b79` (`746b787`) removed the template. Desired state and live state were then equal again, so the Application became `Synced / Healthy` on `746b787` without anything being applied. The `SyncFailed` row for `drill-quota` is the leftover result of the last failed operation, and it is not a live object. The final retry of that operation still targeted `b8c4b79`, as in Task 7, step 8.

**Prediction held.** The `dso202` AppProject has a `namespaceResourceWhitelist` that lists only the kinds the chart needs (Deployment, StatefulSet, Service, ConfigMap, ServiceAccount, Job), and `ResourceQuota` is not among them. Requirement C8 places quotas in the platform layer, which the `platform` project manages. A chart author therefore cannot loosen or replace the namespace limits, even with push access to `main`. This is the least-privilege boundary between the workload and platform projects (section 6.4).

---

## Task 9: Rebuild from Git

**Pending.** Done after Task 8.
