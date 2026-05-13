---
name: deploy-openshift-s2i
description: This skill should be used when the user asks to "deploy to OpenShift", "deploy with s2i", "deploy using source-to-image", "create OpenShift deployment", "oc new-app", "deploy quarkus to openshift", or needs to set up a Quarkus application on OpenShift with a PostgreSQL database using the S2I Java builder workflow.
---

# Deploy Quarkus App to OpenShift with S2I Java

Deploy this Quarkus CRUD microservice to OpenShift using the Source-to-Image (S2I) Java builder. The workflow provisions a PostgreSQL database, builds the application from source, and exposes it via a Route.

## Prerequisites

Before proceeding, verify:

1. `oc` CLI is installed and the user is logged in (`oc whoami`)
2. An OpenShift project/namespace exists or can be created (`oc project`)
3. The application source is pushed to a Git repository accessible from the cluster

Run `scripts/preflight.sh` to validate all prerequisites automatically.

## Deployment Workflow

### Step 1: Create or Select the OpenShift Project

```bash
oc new-project <project-name> --display-name="<Display Name>" || oc project <project-name>
```

If the user does not specify a project name, suggest one derived from the app name (e.g., `customer-api`).

### Step 2: Deploy PostgreSQL

Check if postgres is running, otherwise install postgres as follows:

```bash
oc apply -f https://raw.githubusercontent.com/blues-man/customer-java-skeleton/refs/heads/main/.agents/skills/postgres-k8s/deployment/kubernetes/postgres/deployment.yaml
oc apply -f https://raw.githubusercontent.com/blues-man/customer-java-skeleton/refs/heads/main/.agents/skills/postgres-k8s/deployment/kubernetes/postgres/service.yaml
```

Wait for the pod to be ready before continuing:

```bash
oc rollout status deploy/postgresql-customer --timeout=120s
```

### Step 3: Build and Deploy the Application with S2I

Use the Red Hat UBI8 OpenJDK 17 S2I builder image:

```bash
oc new-app \
  registry.access.redhat.com/ubi8/openjdk-17~<GIT_REPO_URL> \
  --name=<app-name> \
  --build-env=MAVEN_ARGS="package -DskipTests" \
  -e DB_HOST=customerdb \
  -e DB_PORT=5432 \
  -e DB_NAME=customerdb \
  -e DB_USER=customer \
  -e DB_PASSWORD=customer
```

Replace `<GIT_REPO_URL>` with the actual Git repository URL. If the source is in a subdirectory or non-default branch, append `#<branch>` and use `--context-dir=<path>`.

Monitor the build:

```bash
oc logs -f bc/<app-name>
```

Wait for deployment:

```bash
oc rollout status deployment/<app-name> --timeout=300s
```

### Step 4: Expose the Application Route

```bash
oc expose svc/<app-name>
oc get route <app-name> -o jsonpath='{.spec.host}'
```

For TLS-secured routes:

```bash
oc create route edge <app-name>-tls --service=<app-name> --insecure-policy=Redirect
```

### Step 5: Verify the Deployment

```bash
APP_URL=$(oc get route <app-name> -o jsonpath='{.spec.host}')
curl -s http://${APP_URL}/q/health | python3 -m json.tool
curl -s http://${APP_URL}/api/v1/customers | python3 -m json.tool
```

## Configuration via Environment Variables

The application reads database configuration from environment variables with sensible defaults. Set these on the DeploymentConfig or Deployment:

| Variable      | Description              | Default     |
|---------------|--------------------------|-------------|
| `DB_HOST`     | PostgreSQL hostname      | `localhost` |
| `DB_PORT`     | PostgreSQL port          | `5432`      |
| `DB_NAME`     | Database name            | `customerdb`|
| `DB_USER`     | Database username        | `postgres`  |
| `DB_PASSWORD` | Database password        | `postgres`  |

To update after deployment:

```bash
oc set env deployment/<app-name> DB_HOST=<new-host> DB_PASSWORD=<new-pass>
```

## Rebuilding After Code Changes

Trigger a new S2I build from latest source:

```bash
oc start-build <app-name> --follow
```

Or from local directory (binary build):

```bash
oc start-build <app-name> --from-dir=. --follow
```

## Cleanup

Remove all resources for this application:

```bash
oc delete all -l app=<app-name>
oc delete all -l app=customerdb
oc delete pvc -l app=customerdb
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Build fails | `oc logs bc/<app-name>` -- look for Maven errors |
| Pod crash loop | `oc logs deployment/<app-name>` -- check DB connectivity |
| DB connection refused | `oc get pods -l app=customerdb` -- ensure DB pod is running |
| Route not working | `oc get route` -- verify hostname, check `oc get events` |
| Health check fails | Verify `/q/health` path, check `quarkus.http.port=8080` |

## Scripts

- **`scripts/preflight.sh`** -- Validate prerequisites (oc login, project, cluster access)
- **`scripts/deploy.sh`** -- Full deployment automation (DB + app + route)
- **`scripts/teardown.sh`** -- Clean removal of all deployed resources

## References

- **`references/s2i-options.md`** -- Advanced S2I builder options, build hooks, incremental builds, and native image compilation
