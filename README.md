<!--
=============================================================================
File        : README.md
Assignment  : DSO202 Assignment 4 - GitOps Delivery of the Task Tracker with Argo CD
Descriptor  : Unit IV 4.1-4.4, applied to the deliverables of Assignments 1-3
Purpose     : What this repository is, the pinned versions, how to build the
              whole environment from an empty machine, how to clean up, how
              credentials are handled, and the written answers Q1-Q6.
=============================================================================
-->
# dso202-gitops

This repository holds the whole desired state of the DSO202 Task Tracker: the Argo CD installation, the Argo CD projects and Applications, the per-environment platform layer, the Helm chart, and the environment values. An Argo CD instance inside the cluster reads it and makes the cluster match it. After bootstrap, nobody runs `kubectl apply` or `helm install`: a change to the system is a commit.

| Environment | Namespace | Follows | Sync | Frontend |
|---|---|---|---|---|
| dev | `dso202-dev` | branch `main` | automated, prune, self-heal | `http://localhost:30080` |
| staging | `dso202-staging` | a Git tag (now `v1.2.1`) | manual | `kubectl port-forward -n dso202-staging svc/frontend 8081:8080`, then `http://localhost:8081` |

Command output for every task is in [`docs/evidence.md`](docs/evidence.md).

## Pinned versions

| Component | Version | Where it is pinned |
|---|---|---|
| Argo CD | v3.5.6 | `bootstrap/argocd/kustomization.yaml` (install manifest URL tag) |
| `argocd` CLI | v3.5.6 | local tool, matches the server |
| Sealed Secrets Helm chart | 2.20.0 | `argocd/applications/sealed-secrets.yaml` (`targetRevision`) |
| Sealed Secrets controller | 0.40.0 | installed by chart 2.20.0 |
| `kubeseal` CLI | v0.40.0 | local tool, matches the controller |
| kind / node image | kind v0.32.0, `kindest/node:v1.36.1@sha256:3489c767...` | `cluster/kind-cluster.yaml` (node image pinned by digest) |
| kubectl | v1.36.3 | local tool |
| Helm | v4.3.1 | local tool |
| Task Tracker images | `sarojsanyasi/dso202-{db,backend,frontend}:1.0` | `environments/<env>/values.yaml` |
| Release images (Task 7) | `dso202-local/dso202-{frontend,backend}:1.1`, stand-ins built from [`stand-in-images/`](stand-in-images/README.md) | `environments/<env>/values.yaml` |
| Smoke-test image | `busybox:1.37` | `charts/tasktracker/templates/smoke-test-job.yaml` |

## Layout

```text
cluster/kind-cluster.yaml        the kind cluster (single node, host port 30080 mapped)
bootstrap/argocd/                Argo CD install: upstream v3.5.6 manifest + two ConfigMap patches   (applied by hand)
bootstrap/root/                  the 'platform' AppProject and the root Application                (applied by hand)
argocd/projects/                 the 'dso202' workload AppProject                                 (delivered by root)
argocd/applications/             sealed-secrets, platform-{dev,staging}, tasktracker-{dev,staging} (delivered by root)
platform/{dev,staging}/          namespace, quota + limits, RBAC, sealed credentials               (delivered by platform-*)
charts/tasktracker/              the Assignment 3 chart, reduced to the workload layer             (delivered by tasktracker-*)
environments/{dev,staging}/      values that differ per environment
stand-in-images/                 source of the stand-in 1.1 release images used in Task 7 (not deployed by Argo CD)
docs/evidence.md                 command output per task
```

Sync waves in the root Application: `dso202` project (-3), then `sealed-secrets` (-2), then `platform-dev`/`platform-staging` (-1), then `tasktracker-dev`/`tasktracker-staging` (0). Inside the chart: database (0), backend (1), frontend (2), then the PostSync smoke test.

## Build the whole environment from an empty machine

Prerequisites: Docker, kind, kubectl, Helm, git, `argocd` v3.5.6 and `kubeseal` v0.40.0 on the PATH. You also need the sealing-key backup `../dso202-keys/sealing-key.backup.yaml`, which is kept outside this repository.

```bash
git clone https://github.com/Kinley-pal8/dso202-gitops.git
cd dso202-gitops

# 1. Cluster (host port 30080 must be free)
kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml

# 2. Restore the sealing key BEFORE the controller exists, so it reuses the key
kubectl create namespace sealed-secrets
kubectl apply -f ../dso202-keys/sealing-key.backup.yaml

# 3. Install Argo CD (server-side: the ApplicationSet CRD is too large for client-side apply)
kubectl apply -k bootstrap/argocd --server-side --force-conflicts
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=600s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=600s

# 4. Hand over to Git: the platform project and the root Application
kubectl apply -f bootstrap/root

# 5. Watch the Applications appear in wave order
kubectl get applications -n argocd -w

# 6. Sign in, then sync staging (manual by design)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd app sync tasktracker-staging
```

If Docker Hub refuses an image (rate limit, or "no match for platform in manifest"), load the issued images from the host. This does not change any tag:

```bash
for i in sarojsanyasi/dso202-db:1.0 sarojsanyasi/dso202-backend:1.0 sarojsanyasi/dso202-frontend:1.0; do
  kind load docker-image "$i" --name dso202-gitops
done
```

The Task 7 release images are not on any registry, so after a rebuild they must be built and loaded before Argo CD syncs dev and staging:

```bash
docker build -t dso202-local/dso202-frontend:1.1 stand-in-images/frontend
docker build -t dso202-local/dso202-backend:1.1  stand-in-images/backend
kind load docker-image dso202-local/dso202-frontend:1.1 dso202-local/dso202-backend:1.1 --name dso202-gitops
```

## Cleanup

```bash
# Stop any port-forwards, then delete the cluster (removes everything, including database contents)
kind delete cluster --name dso202-gitops
# The repository and ../dso202-keys/ are untouched; keep the key backup if the
# environment is to be rebuilt with the same SealedSecrets.
```

Do not delete the `root` Application to "clean up" inside a running cluster. Its finalizer cascades to every child Application and every workload.

## How credentials are handled

- The chart never renders a `Secret`. Pods read `tasktracker-credentials` through `existingSecret` (chart contract C3).
- That Secret is created in each namespace by the Sealed Secrets controller from `platform/<env>/tasktracker-credentials.sealed.yaml`. That file holds ciphertext produced by `kubeseal` with this cluster's public key, so it is safe to commit.
- The plaintext input (`secrets-plain/<env>.env`) is git-ignored and never committed. It was piped through `kubectl create secret --dry-run=client -o yaml | kubeseal`, so the plaintext Secret was never written to disk. Dev and staging use different passwords and are sealed separately: strict scope ties each file to its own name and namespace.
- The sealing key (the controller's private key) is backed up to `../dso202-keys/sealing-key.backup.yaml` with mode 600, outside the repository. It is the one piece of state that is neither in Git nor reproducible.
- Proof that nothing leaked: a `git log -p --all -S'<value>'` search for every credential value returns nothing (Task 4, step 7 in the evidence).

## Deviations from the brief and from earlier assignments

| What | Why |
|---|---|
| `cluster/kind-cluster.yaml` maps only host port 30080, has no `ingress-ready` label, and pins the node image by digest | No ingress controller is used. Host port 8080 is needed for the Argo CD port-forward. Design rule 3 requires pinned versions. |
| LimitRange `min` lowered from 50m/64Mi (Assignment 2) to 10m/16Mi | The smoke-test Job (Listing 13) requests 10m/16Mi, and a LimitRange minimum applies to requests too, so the old minimum rejected the hook Pod. |
| The DbBackup operator, its CRD, and the cluster-scoped ClusterRoles of Assignment 2/3 are not carried over | They are cluster-scoped, which the `dso202` project forbids (C8). Nothing in this assignment uses them. |
| Chart objects keep fixed names (`db`, `backend`, `frontend`) | The backend reaches the database at host `db`, and the release name is fixed to `tasktracker` in both Applications. The smoke test calls `http://backend:8080/api/tasks`. |
| The `1.0` images were loaded into kind from the host | Docker Hub returned "no match for platform in manifest" for `sarojsanyasi/dso202-db:1.0`. Section 13 of the brief prescribes this remedy. |
| Task 7 uses stand-in `1.1` images, `dso202-local/dso202-{frontend,backend}:1.1`, built from `stand-in-images/` | The tutor-issued `1.1` tags were never published on Docker Hub, and the module tutor instructed me to build my own. Each one matches its section 8 release note, and the backend's undocumented `DB_POOL_MAX` requirement recreates the intended failure. They are loaded with `kind load`, so they must be loaded again after a rebuild. |
| Task 7 pull requests were merged with merge commits, not squashed | Squash merging is only recommended. The revert therefore used `git revert -m 1`, as the brief describes for this case. |
| The chart adds a `frontend-nginx` ConfigMap that forwards `/api/` to the backend, and `frontend.config.BACKEND_URL` is `"."` | The browser calls the API itself. Without an Ingress (C9) it had no route to the ClusterIP backend, and the image turns an empty `BACKEND_URL` into `http://localhost:8080`. See "Corrections after Task 9" in the evidence. |
| The `dso202` whitelist also names `ReplicaSet` and `Pod`, which the chart does not render | Argo CD hides child objects of kinds the project does not permit, so without them no Pods or logs were visible, and Task 6's logs permission could not be used. This adds no capability, because Deployments, StatefulSets and Jobs already create Pods. |

## Written answers

### Q1: Why is `platform` applied by hand while `dso202` is created by the root, and what is the risk if `dso202` may deploy into `argocd`?

The root Application has to belong to a project, and that project must already exist when the root is created, or Argo CD rejects it. `platform` is therefore part of the bootstrap: it is the one project that must exist before Git can deliver anything. `platform` is also the administrator-level project. It may deploy any kind, including cluster-scoped ones, into `argocd`, `sealed-secrets` and both workload namespaces, so it deliberately lives in the hand-applied layer. Only someone with cluster-admin access to `kubectl` can change it.

`dso202` is an ordinary, narrow project, so it is declared like everything else: a file under `argocd/projects/`, created and kept in shape by the root (sync wave -3, before any Application refers to it). A hand edit to it is reverted by self-heal, and a change to it is a reviewed commit.

If `dso202` were allowed to deploy into `argocd`, a commit to the chart could add an `Application` or `AppProject` manifest. Argo CD would create that object in its own namespace, where Applications and AppProjects are read as configuration. The new Application could name the `platform` project, or a new project with `*` permissions, and so deploy anything anywhere, including cluster-scoped kinds. The workload project would then be able to widen its own permissions. That is administrator capability, and it defeats the least-privilege split in section 6.4.

### Q2: What does strict scope prevent, and what is lost, and what must be done, if the sealing key is lost?

With strict scope (the default), the name and namespace of the Secret are part of the encrypted payload. The ciphertext in `platform/dev/tasktracker-credentials.sealed.yaml` therefore decrypts only as a Secret named `tasktracker-credentials` in `dso202-dev`. This prevents someone who can create objects in another namespace from copying the SealedSecret there, or renaming it, to get the dev credentials decrypted for a workload of their choosing. It is also why dev and staging are sealed separately.

If the sealing key is lost, for example because the cluster is deleted and there is no backup or the backup is older than a key renewal:
- **What is lost:** every SealedSecret in Git becomes permanently undecryptable. It was encrypted to a public key whose private half no longer exists. The Git history is intact but useless for these files.
- **What still works:** Secrets that the controller already created in a still-running cluster keep working until they are deleted.
- **What must be done:**
  1. Let the new controller generate a new key pair.
  2. Recover the plaintext credentials from the password manager, or rotate them: create new passwords and change them in PostgreSQL.
  3. Re-seal every environment with `kubeseal` against the new controller and commit the new files.
  4. Take a fresh backup of the new key.
- **If the database password changed:** the database contents, which live on the PVC, have to be migrated or re-initialised to accept the new password.

### Q3: What is the difference between `Synced` and `Healthy`? Example of `Synced` but not `Healthy`.

- **Sync status** compares desired state with live state. `Synced` means every object rendered from Git exists in the cluster with the same spec.
- **Health** describes whether the live objects are working. A Deployment is `Healthy` only when its new ReplicaSet has the desired number of available Pods. A StatefulSet is `Healthy` when its rolling update is complete and the Pods are ready.

The two are independent. Argo CD can apply a manifest perfectly and still have the result not work.

Example from this assignment. When the Sealed Secrets Application was first created (Task 4), it was polled every 10 s:

```text
2 Synced/Progressing
...
6 Synced/Progressing
7 Synced/Healthy
```

For about a minute, the Deployment, CRD and Service existed exactly as declared (`Synced`), but the controller Pod was still pulling its image and was not ready (`Progressing`).

The same thing happened in dev in Task 5. The objects were applied, but `db-0` was in `ImagePullBackOff`, so `tasktracker-dev` stayed `Progressing` until the image was available. Because of the restored Application health check, `root` showed `Synced / Progressing` at the same time (Task 5 watch in the evidence).

To provoke a lasting case, commit a non-existent image tag to `environments/dev/values.yaml`. The Application becomes `Synced`, because the Deployment matches Git. After `progressDeadlineSeconds` (120 s, contract C6) it becomes `Degraded`, because the new Pods never become ready. Task 7 does exactly this with the faulty backend release.

### Q4: What does Argo CD RBAC control, what does Kubernetes RBAC control, and where is each configured? What would change with SSO?

| | Argo CD RBAC | Kubernetes RBAC (Assignment 2) |
|---|---|---|
| Controls | What an Argo CD user or group may do through the Argo CD API server, UI and CLI: get, sync, create or delete Applications, read projects, read logs, exec, and so on, scoped by project and Application (`dso202/*`). | What an identity (user, group or ServiceAccount) may do through the Kubernetes API: verbs on resources in a namespace or cluster-wide. |
| Configured in | `argocd-rbac-cm` (`policy.csv`, `policy.default`), here `bootstrap/argocd/argocd-rbac-cm-patch.yaml`. Accounts in `argocd-cm` (`accounts.reviewer`). Also project roles in AppProjects. | `Role`/`ClusterRole` and `RoleBinding`/`ClusterRoleBinding` objects, here `platform/<env>/rbac.yaml`. |
| Enforced by | the Argo CD API server | the Kubernetes API server |

They are layered. Argo CD's controller acts in the cluster with its own powerful ServiceAccount, so a user who may `sync` in Argo CD changes the cluster without having any Kubernetes RBAC of their own. Conversely, `viewer`'s Kubernetes Role gives that ServiceAccount nothing in Argo CD. In this task `reviewer` exists only in Argo CD.

With SSO (OIDC or Dex connected to the organisation's identity provider), users would no longer be local accounts. `accounts.reviewer: login` and `argocd account update-password` would go away. `policy.csv` would grant permissions to identity-provider groups (or users), read from the token's `groups` claim, instead of to local account names. For example, a role is defined once, then a group is bound to it:

```text
p, role:reviewer, applications, get, dso202/*, allow
p, role:reviewer, logs, get, dso202/*, allow
g, dso202-reviewers, role:reviewer
```

Granting access then becomes a membership change in the identity provider, not an edit to `policy.csv`. The OIDC settings themselves (`oidc.config` or `dex.config`, plus `url`) would go in `argocd-cm`, and `scopes` in `argocd-rbac-cm` would name the claim that carries the groups.

### Q5: Why is `argocd app rollback` refused, what is the GitOps equivalent, and why is `git revert` preferred?

**Why it is refused.** In Task 7 the command printed `rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled`. `argocd app rollback` re-deploys a revision from the Application's history. It does not change Git. `tasktracker-dev` has automated sync with self-heal, so its desired state is "whatever `main` says". A rollback would make the live state differ from Git on purpose, and the next reconciliation would treat that as drift and sync it straight back to the bad commit. Argo CD therefore refuses rather than start a fight it would lose. Rollback is only allowed on an Application with manual sync, and even there it leaves the Application `OutOfSync` with Git, which breaks the principle that Git is the single source of truth.

**The GitOps equivalent** is to change the desired state: commit to Git the content you want to run, and let the controller reconcile. In Task 7 that was `git revert -m 1 0a3267f`, merged through pull request #4. Dev returned to backend `1.0` with no command run against the cluster. The second option, used in pull request #5, is to fix forward: keep the new release and supply what it needs (`DB_POOL_MAX`) as a value. For staging, which follows a tag, the equivalent of a rollback is to set `targetRevision` back to the previous tag and sync.

**Why `git revert` and not deleting the commit from history:**
- **It records what happened.** `revert` adds a new commit that undoes the change. The history keeps both the bad commit and its reversal, with who did each and why. That is the audit trail GitOps promises (principle 2: versioned and immutable).
- **It is safe for everyone else.** Removing the commit (`git reset` plus a force-push) rewrites `main`. Every clone, open branch and pull request based on the old history breaks or reintroduces the commit, and branch protection usually forbids force-pushes to `main`.
- **It keeps deployed revisions resolvable.** Argo CD's history and any tags refer to commit SHAs. A rewritten history leaves those SHAs dangling, so "what was running at 22:46" can no longer be answered from Git.
- **It goes through the same path as any change.** The revert was a reviewed pull request, picked up by Argo CD like every other commit. No special access was needed.
- **It can be undone or replaced.** In Task 7, the release was later fixed forward on top of the revert, with nothing lost.

### Q6: (a) Single repository: two advantages, two disadvantages. (b) What is not under GitOps control after the rebuild?

**(a) One repository for the chart and the environment configuration.**

Advantages:
- **A change that spans chart and values is one reviewed commit.** For example, a new template together with the values that switch it on, or a release together with the configuration it needs. In Task 7, pull request #5 changed the image and added `DB_POOL_MAX` in one atomic change. If it had to be reverted, one `git revert` would remove both halves, with no window in which the chart and values of two repositories disagree.
- **A tag freezes everything at once.** Staging follows `v1.2.0`, and that single reference pins the chart templates, the values and the Application definitions together. Promotion is moving one tag, and `argocd app history` names one SHA that fully describes what ran. The rebuild in Task 9 needed one clone and one key, and nothing else had to be versioned in step.

Disadvantages:
- **Every change to the chart reaches every environment that follows `main`, and all readers share one history.** Drill 4 showed it: a template added to the chart for any reason went straight to dev, and docs-only commits are new revisions for every Application too. With configuration separate from source, the chart is versioned and released on its own (for example as a packaged chart with a semantic version), and each environment opts into a chart version explicitly.
- **Access cannot be separated by repository.** Anyone who may merge to `main` may change the chart, the values of every environment, and the Argo CD projects and Applications under `argocd/`, including widening the `dso202` whitelist that Drill 4 relied on. Separate repositories let a team give developers the application or chart repository and restrict the configuration repository to the people who approve releases. In a single repository this needs CODEOWNERS and branch protection to approximate.

**(b) What is not under GitOps control after the rebuild, and how production teams handle it.**

| Not under GitOps control | How a production team usually handles it |
|---|---|
| The cluster itself. `cluster/kind-cluster.yaml` is in Git, but `kind create cluster` was run by hand. | The cluster is provisioned by infrastructure as code (Terraform, Cluster API or Crossplane) from its own reviewed repository and pipeline. |
| The bootstrap layer: the Argo CD installation and its two ConfigMap patches, applied with `kubectl apply -k`. | After a one-off install by the provisioning pipeline, Argo CD manages its own installation through an Application that points at the same bootstrap directory ("Argo CD manages Argo CD"). |
| The root Application and the `platform` project, applied with `kubectl apply -f bootstrap/root`. | They are created by the same automated bootstrap, for example the Terraform Argo CD provider or Helm values, and are often owned by a central platform Argo CD that manages many clusters. |
| The sealing key: backed up and restored by hand from `../dso202-keys/`. | The key, or the credentials themselves, live in a managed secret store (Vault, a cloud KMS or secrets manager). The bootstrap restores the key from there, or the External Secrets Operator replaces SealedSecrets altogether. |
| The database contents, which were lost. | A managed database service, or scheduled backups (`pg_dump` or Velero snapshots to object storage, with point-in-time recovery), are restored as a separate, regularly rehearsed step. |
| Argo CD's local passwords: the new `admin` initial password, and the `reviewer` password in `argocd-secret`, which had to be set again by hand. | Local accounts are disabled in favour of SSO (OIDC). Identities and group membership live in the identity provider, and only the group-to-role mapping is in Git. |
| The images that `kind load` placed in the node: the `1.0` images that do not pull on this host, and the stand-in `1.1` images. | Images are built by CI from a tagged commit, pushed to a registry, and pulled by digest. Nothing is copied into nodes by hand. |
| The manual sync of staging and the `kubectl port-forward` sessions. | Both are deliberate. A production promotion step is a pull request plus a sync started by an approved person or pipeline, and the UI is exposed through an Ingress with SSO instead of a port-forward. |
