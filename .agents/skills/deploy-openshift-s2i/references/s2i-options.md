# Advanced S2I Builder Options

## Builder Images

| Image | Java Version | Registry |
|-------|-------------|----------|
| `ubi8/openjdk-17` | 17 (recommended) | `registry.access.redhat.com` |
| `ubi8/openjdk-21` | 21 | `registry.access.redhat.com` |
| `ubi8/openjdk-11` | 11 (legacy) | `registry.access.redhat.com` |
| `ubi9/openjdk-17` | 17 (UBI 9) | `registry.access.redhat.com` |
| `ubi9/openjdk-21` | 21 (UBI 9) | `registry.access.redhat.com` |

## Build Environment Variables

Control the S2I build behavior via `--build-env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `MAVEN_ARGS` | `package -DskipTests` | Maven goals and flags |
| `MAVEN_ARGS_APPEND` | _(empty)_ | Extra args appended to MAVEN_ARGS |
| `MAVEN_MIRROR_URL` | _(empty)_ | Maven mirror/proxy (e.g., Nexus) |
| `MAVEN_S2I_ARTIFACT_DIRS` | `target` | Where to find built artifacts |
| `S2I_SOURCE_DEPLOYMENTS_FILTER` | `*.jar` | Which artifacts to copy to runtime |
| `JAVA_APP_DIR` | `/deployments` | Target directory in the runtime image |
| `MAVEN_CLEAR_REPO` | `false` | Clear local Maven repo after build to shrink image |

Example with a corporate Maven mirror:

```bash
oc new-app \
  registry.access.redhat.com/ubi8/openjdk-17~<GIT_URL> \
  --name=my-app \
  --build-env=MAVEN_MIRROR_URL=https://nexus.corp.example.com/repository/maven-public/ \
  --build-env=MAVEN_ARGS="package -DskipTests -Dquarkus.package.type=fast-jar"
```

## Incremental Builds

Reuse Maven dependencies from previous builds to speed up subsequent builds:

```bash
oc patch bc/<app-name> -p '{"spec":{"strategy":{"sourceStrategy":{"incremental":true}}}}'
oc start-build <app-name> --follow
```

## Binary Builds (from local source)

Build directly from the working directory without pushing to Git:

```bash
oc new-build --name=<app-name> \
  --image-stream=ubi8-openjdk-17 \
  --binary=true

oc start-build <app-name> --from-dir=. --follow

oc new-app <app-name> \
  -e DB_HOST=customerdb \
  -e DB_PORT=5432 \
  -e DB_NAME=customerdb \
  -e DB_USER=customerdb_user \
  -e DB_PASSWORD=customerdb_pass
```

## Native Image Compilation

Build a Quarkus native executable inside S2I (requires more memory and build time):

```bash
oc new-app \
  registry.access.redhat.com/ubi8/openjdk-17~<GIT_URL> \
  --name=<app-name>-native \
  --build-env=MAVEN_ARGS="package -Pnative -DskipTests" \
  --build-env=MAVEN_OPTS="-Xmx4g"

oc patch bc/<app-name>-native -p '{"spec":{"resources":{"limits":{"memory":"6Gi","cpu":"4"}}}}'
oc start-build <app-name>-native --follow
```

## Build Hooks

Run a script after the S2I assemble step:

```bash
mkdir -p .s2i/bin
cat > .s2i/bin/assemble <<'HOOK'
#!/bin/bash
/usr/local/s2i/assemble
echo "--- Running post-assemble hook ---"
# custom steps here, e.g., download config, run flyway info
HOOK
chmod +x .s2i/bin/assemble
```

## Resource Limits on Builds

Prevent OOM kills during Maven builds:

```bash
oc patch bc/<app-name> -p '{
  "spec": {
    "resources": {
      "limits": {"memory": "2Gi", "cpu": "2"},
      "requests": {"memory": "1Gi", "cpu": "500m"}
    }
  }
}'
```

## Using OpenShift Secrets for Database Credentials

Instead of plaintext environment variables, reference a Secret:

```bash
oc create secret generic customerdb-credentials \
  --from-literal=DB_USER=customerdb_user \
  --from-literal=DB_PASSWORD=customerdb_pass \
  --from-literal=DB_HOST=customerdb \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=customerdb

oc set env deployment/<app-name> --from=secret/customerdb-credentials
```

## Health Probes

Configure liveness and readiness probes for the Quarkus application:

```bash
oc set probe deployment/<app-name> \
  --liveness \
  --get-url=http://:8080/q/health/live \
  --initial-delay-seconds=15 \
  --period-seconds=10

oc set probe deployment/<app-name> \
  --readiness \
  --get-url=http://:8080/q/health/ready \
  --initial-delay-seconds=5 \
  --period-seconds=5
```

## Webhook Triggers

Set up automatic builds on Git push:

```bash
WEBHOOK_URL=$(oc describe bc/<app-name> | grep -A1 "GitHub" | tail -1 | awk '{print $NF}')
echo "Configure this webhook URL in your Git repository: $WEBHOOK_URL"
```

For generic Git webhooks:

```bash
WEBHOOK_URL=$(oc describe bc/<app-name> | grep -A1 "Generic" | tail -1 | awk '{print $NF}')
```
