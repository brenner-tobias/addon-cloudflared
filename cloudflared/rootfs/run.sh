#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Cloudflared
# Runs the Cloudflare Tunnel for Home Assistant
# ==============================================================================
declare config_file="/tmp/config.json"
declare certificate="/data/cert.pem"
declare -a options

# Set common cloudflared tunnel options
options+=(--no-autoupdate)
options+=(--metrics="0.0.0.0:36500")

# Check for post_quantum option
if bashio::config.true 'post_quantum'; then
    bashio::log.trace "bashio::config.true 'post_quantum'"
    options+=(--post-quantum)
fi

# Check for additional run parameters
if bashio::config.has_value 'run_parameters'; then
    bashio::log.trace "bashio::config.has_value 'run_parameters'"
    for run_parameter in $(bashio::config 'run_parameters'); do
        bashio::log.trace "Adding run_parameter: ${run_parameter}"
        options+=("${run_parameter}")
    done
fi

# Check if we run local or remote managed tunnel and set related options
if bashio::config.has_value 'tunnel_token'; then
    bashio::log.trace "bashio::config.has_value 'tunnel_token'"
    options+=(run --token="$(bashio::config 'tunnel_token')")
else
    bashio::log.debug "using ${config_file} config file"
    options+=(--origincert="${certificate}")
    options+=(--config="${config_file}")
    options+=(run "$(bashio::config 'tunnel_name')")
fi

function wait_for_file() {
    local file="$1"
    local timeout="$2"
    local interval=1
    local elapsed=0

    while [[ ! -f "${file}" && ${elapsed} -lt ${timeout} ]]; do
        sleep "${interval}"
        elapsed=$((elapsed + interval))
    done

    if [[ ! -f "${file}" ]]; then
        bashio::exit.nok "Timed out waiting for ${file} to be created."
    fi
}

if [[ ! -f /dev/shm/no_built_in_proxy ]]; then
    bashio::log.info "Waiting for Caddy to be ready..."
    wait_for_file /data/caddy/pki/authorities/local/root.crt 15
    if
        curl --fail --silent --show-error --output /dev/null \
            --max-time 1 --retry 15 --retry-delay 1 --retry-connrefused \
            --cacert /data/caddy/pki/authorities/local/root.crt \
            https://caddy.localhost/healthz
    then
        bashio::log.info "Caddy is ready."
    else
        bashio::exit.nok "Caddy did not become ready in time, aborting."
    fi
fi

bashio::log.info "Connecting Cloudflare Tunnel..."
bashio::log.debug "cloudflared tunnel ${options[*]}"
exec cloudflared tunnel "${options[@]}"
