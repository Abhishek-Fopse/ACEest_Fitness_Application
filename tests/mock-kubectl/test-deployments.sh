#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOCK_DIR="$ROOT_DIR/tests/mock-kubectl"
MOCK_BIN="$MOCK_DIR/bin"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

export PATH="$MOCK_BIN:$PATH"
export MOCK_STATE_DIR="$STATE"

PASS_COUNT=0
FAIL_COUNT=0

reset_state() {
    local color="$1"

    mkdir -p "$STATE"
    printf '%s' "$color" > "$STATE/service-color"
    printf '%s' "abhishekfopse/aceest-fitness:old" \
        > "$STATE/aceest-fitness-blue.image"
    printf '%s' "abhishekfopse/aceest-fitness:old" \
        > "$STATE/aceest-fitness-green.image"
    : > "$STATE/commands.log"

    unset MOCK_HEALTH_FAIL_COLOR
    unset MOCK_ENDPOINT_FAIL_COLOR
    unset MOCK_ROLLOUT_FAIL_COLOR
    unset MOCK_READY_FAIL_COLOR
}

assert_color() {
    local expected="$1"
    local actual
    actual="$(cat "$STATE/service-color")"

    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Expected Service colour $expected, found $actual"
        return 1
    fi
}

run_success() {
    local name="$1"
    shift

    echo
    echo "TEST: $name"

    if "$@"; then
        echo "PASS: $name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_failure() {
    local name="$1"
    shift

    echo
    echo "TEST: $name"

    if "$@"; then
        echo "FAIL: $name (command unexpectedly succeeded)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "PASS: $name (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
}

deploy_script="$ROOT_DIR/scripts/blue-green-deploy.sh"
rollback_script="$ROOT_DIR/scripts/blue-green-rollback.sh"

# 1. Successful Blue-to-Green deployment.
reset_state blue
run_success "Blue-to-Green deployment" \
    bash -c '"$1" test-build-001' _ "$deploy_script"
assert_color green || FAIL_COUNT=$((FAIL_COUNT + 1))

# 2. Candidate health failure must preserve Blue traffic.
reset_state blue
export MOCK_HEALTH_FAIL_COLOR=green
run_failure "Candidate health failure" \
    bash -c '"$1" test-build-002' _ "$deploy_script"
assert_color blue || FAIL_COUNT=$((FAIL_COUNT + 1))

# 3. Candidate endpoint failure must restore Blue traffic.
reset_state blue
export MOCK_ENDPOINT_FAIL_COLOR=green
run_failure "Candidate endpoint failure and traffic restoration" \
    bash -c '"$1" test-build-003' _ "$deploy_script"
assert_color blue || FAIL_COUNT=$((FAIL_COUNT + 1))

# 4. Successful Green-to-Blue rollback.
reset_state green
run_success "Green-to-Blue rollback" \
    bash "$rollback_script"
assert_color blue || FAIL_COUNT=$((FAIL_COUNT + 1))

# 5. Rollback target health failure must preserve Green traffic.
reset_state green
export MOCK_HEALTH_FAIL_COLOR=blue
run_failure "Rollback target health failure" \
    bash "$rollback_script"
assert_color green || FAIL_COUNT=$((FAIL_COUNT + 1))

# 6. Failed rollback endpoint must restore original Green traffic.
reset_state green
export MOCK_ENDPOINT_FAIL_COLOR=blue
run_failure "Rollback endpoint failure and original traffic restoration" \
    bash "$rollback_script"
assert_color green || FAIL_COUNT=$((FAIL_COUNT + 1))

echo
echo "=============================="
echo "Mock Kubernetes test summary"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "=============================="

if (( FAIL_COUNT > 0 )); then
    exit 1
fi