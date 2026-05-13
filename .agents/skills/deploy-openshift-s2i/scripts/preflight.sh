#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    echo "[OK]   $label"
    ((PASS++))
  else
    echo "[FAIL] $label"
    ((FAIL++))
  fi
}

echo "=== OpenShift S2I Deployment Preflight ==="
echo ""

check "oc CLI installed"          command -v oc
check "Logged in to cluster"      oc whoami
check "Project selected"          oc project -q
check "Can list pods"             oc get pods --no-headers
check "Maven wrapper present"     test -f ./mvnw
check "pom.xml present"           test -f ./pom.xml
check "S2I builder image accessible" oc image info registry.access.redhat.com/ubi8/openjdk-17 --filter-by-os=linux/amd64

echo ""
echo "--- Result: $PASS passed, $FAIL failed ---"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Fix the failed checks before deploying."
  exit 1
fi
