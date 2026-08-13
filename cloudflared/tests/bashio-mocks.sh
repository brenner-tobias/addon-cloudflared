# Bashio helper mocks used for local shell unit tests.
# This file is intended to be sourced by shell test harnesses.

declare -Ag TEST_CONFIG
TEST_CONFIG=()

bashio::log.trace() { :; }
bashio::log.info() { :; }
bashio::log.debug() { :; }
bashio::log.notice() { :; }
bashio::log.warning() { :; }
bashio::log.error() { :; }

bashio::config.has_value() {
    local key="$1"
    [[ -n "${TEST_CONFIG[$key]:-}" ]]
}

bashio::config.is_empty() {
    local key="$1"
    [[ -z "${TEST_CONFIG[$key]:-}" ]]
}

bashio::config.exists() {
    local key="$1"
    [[ -v TEST_CONFIG[$key] ]]
}

bashio::config.true() {
    local key="$1"
    local value="${TEST_CONFIG[$key]:-}"
    case "${value}" in
        true|1|TRUE|yes|YES) return 0;;
        *) return 1;;
    esac
}

bashio::config() {
    local key="$1"
    printf '%s' "${TEST_CONFIG[$key]:-}"
}

bashio::addon.config() {
    printf '%s' "${TEST_ADDON_CONFIG:-{}}"
}

bashio::var.is_empty() {
    [[ -z "${1:-}" ]]
}

bashio::var.true() {
    case "${1:-}" in
        true|1|TRUE|yes|YES) return 0;;
        *) return 1;;
    esac
}

bashio::exit.nok() {
    echo "ERROR: $*" >&2
    exit 1
}

bashio::exit.ok() {
    exit 0
}

bashio::fs.file_exists() {
    [[ -f "$1" ]]
}

bashio::jq() {
    if [[ $# -gt 0 ]]; then
        printf '%s' "${1}"
    fi
}
