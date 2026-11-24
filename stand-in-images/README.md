# Stand-in `1.1` images

The tutor-issued `sarojsanyasi/dso202-frontend:1.1` and
`sarojsanyasi/dso202-backend:1.1` tags were not published on Docker Hub
(only `1.0` exists). The module tutor instructed me to build my own `1.1` images.
This folder is their source, so the result can be reproduced and inspected.

They are tagged `dso202-local/<name>:1.1`, a name that is clearly not the
tutor's repository, and loaded straight into the kind node. They are not
pushed to any registry.

| Image | Built from | Change from `1.0` (matches the section 8 release note) |
|---|---|---|
| `dso202-local/dso202-frontend:1.1` | `frontend/` | The page header shows `release 1.1` (`public/index.html`, `public/styles.css`). Nothing else. |
| `dso202-local/dso202-backend:1.1` | `backend/` | Configuration loading moved into `src/config.js`. The API is unchanged. The new loader also requires `DB_POOL_MAX`, which the release note does not mention; without it the process exits with code 1 at start-up. |

The backend's undocumented requirement is deliberate. It recreates the
situation Task 7 is built around: the release note says "internal
refactoring", but only the container logs say what the image needs.

## Build and load

```bash
docker build -t dso202-local/dso202-frontend:1.1 stand-in-images/frontend
docker build -t dso202-local/dso202-backend:1.1  stand-in-images/backend
kind load docker-image dso202-local/dso202-frontend:1.1 dso202-local/dso202-backend:1.1 --name dso202-gitops
```

The chart uses `imagePullPolicy: IfNotPresent`, so the kubelet uses the
loaded copies and never contacts a registry for them. After a cluster
rebuild (Task 9), run the `kind load` again before Argo CD syncs the
Applications.

## Check the start-up failure locally

```bash
docker run --rm dso202-local/dso202-backend:1.1
# [config] FATAL: required environment variable DB_POOL_MAX is not set (maximum number of database connections, a positive integer such as "10")
```
