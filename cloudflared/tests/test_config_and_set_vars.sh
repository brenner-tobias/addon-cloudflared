#!/usr/bin/env bash
# SC1091: sourced test helpers are loaded dynamically and ShellCheck cannot resolve them here.
# SC2034: TEST_CONFIG is used via indirect associative-array access in the Bashio mock layer.
# SC2154: variables like ha_url/tunnel_name are populated by validateConfigAndSetVars in the sourced app script.
# shellcheck disable=SC1091,SC2034,SC2154
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=./bashio-mocks.sh
source "${ROOT_DIR}/tests/bashio-mocks.sh"
# shellcheck source=../rootfs/etc/s6-overlay/s6-rc.d/prepare/run.sh
source "${ROOT_DIR}/rootfs/etc/s6-overlay/s6-rc.d/prepare/run.sh"

external_hostname=""
ha_url=""
tunnel_name=""

# Basic assertions
assert_eq() {
    local expected="$1"
    local actual="$2"
    local name="$3"

    if [[ "${actual}" != "${expected}" ]]; then
        echo "FAIL: ${name}: expected '${expected}', got '${actual}'"
        exit 1
    fi
}

assert() {
    local condition="$1"
    local name="$2"

    if ! eval "${condition}"; then
        echo "FAIL: ${name}"
        exit 1
    fi
}

TEST_FAILURES=0

run_test() {
    local test_name="$1"

    set +e
    "${test_name}"
    local rc=$?
    set -e

    if [[ ${rc} -ne 0 ]]; then
        echo "FAIL: ${test_name}"
        TEST_FAILURES=$((TEST_FAILURES + 1))
    else
        echo "PASS: ${test_name}"
    fi
}

test_with_storage_http() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant/.storage"
    cp "${ROOT_DIR}/tests/resources/http-v1.json" "${tmpdir}/homeassistant/.storage/http"

    mkdir -p "${tmpdir}/homeassistant"
    cp "${ROOT_DIR}/tests/resources/config-basic.yaml" "${tmpdir}/homeassistant/configuration.yaml"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    export HOMEASSISTANT_STORAGE_HTTP="${tmpdir}/homeassistant/.storage/http"

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "http://homeassistant:80" "${ha_url}" "ha_url from storage http"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_storage_http_ssl() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant/.storage"
    cp "${ROOT_DIR}/tests/resources/http-v1-ssl.json" "${tmpdir}/homeassistant/.storage/http"

    mkdir -p "${tmpdir}/homeassistant"
    cp "${ROOT_DIR}/tests/resources/config-basic.yaml" "${tmpdir}/homeassistant/configuration.yaml"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    export HOMEASSISTANT_STORAGE_HTTP="${tmpdir}/homeassistant/.storage/http"

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "https://homeassistant:443" "${ha_url}" "ha_url from storage http"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_storage_http_v2() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant/.storage"
    cp "${ROOT_DIR}/tests/resources/http-v2.json" "${tmpdir}/homeassistant/.storage/http"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    export HOMEASSISTANT_STORAGE_HTTP="${tmpdir}/homeassistant/.storage/http"

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "http://homeassistant:80" "${ha_url}" "ha_url from storage http v2"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_storage_http_v2_ssl() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant/.storage"
    cp "${ROOT_DIR}/tests/resources/http-v2-ssl.json" "${tmpdir}/homeassistant/.storage/http"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    export HOMEASSISTANT_STORAGE_HTTP="${tmpdir}/homeassistant/.storage/http"

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "https://homeassistant:443" "${ha_url}" "ha_url from storage http v2"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_configuration_yaml_only() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant"
    cp "${ROOT_DIR}/tests/resources/config-basic.yaml" "${tmpdir}/homeassistant/configuration.yaml"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    unset HOMEASSISTANT_STORAGE_HTTP

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "https://homeassistant:443" "${ha_url}" "ha_url from configuration.yaml"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_default_config_only() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant"
    cp "${ROOT_DIR}/tests/resources/config-default.yaml" "${tmpdir}/homeassistant/configuration.yaml"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    unset HOMEASSISTANT_STORAGE_HTTP

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "http://homeassistant:8123" "${ha_url}" "ha_url from default_config-only configuration.yaml"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

test_with_unknown_config_version() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    mkdir -p "${tmpdir}/homeassistant/.storage"
    cp "${ROOT_DIR}/tests/resources/http-v-1.json" "${tmpdir}/homeassistant/.storage/http"

    export HOMEASSISTANT_CONFIG_FILE="${tmpdir}/homeassistant/configuration.yaml"
    export HOMEASSISTANT_STORAGE_HTTP="${tmpdir}/homeassistant/.storage/http"

    TEST_CONFIG=(
        [external_hostname]="example.com"
    )

    validateConfigAndSetVars

    assert_eq "http://homeassistant:80" "${ha_url}" "ha_url from unknown storage version"
    assert_eq "homeassistant" "${tunnel_name}" "default tunnel_name"

    rm -rf "${tmpdir}"
}

main() {
    run_test test_with_storage_http
    run_test test_with_storage_http_ssl
    run_test test_with_storage_http_v2
    run_test test_with_storage_http_v2_ssl
    run_test test_with_configuration_yaml_only
    run_test test_with_default_config_only
    run_test test_with_unknown_config_version

    if [[ ${TEST_FAILURES} -ne 0 ]]; then
        echo "${TEST_FAILURES} test(s) failed."
        exit 1
    fi

    echo "All tests passed."
}

main
