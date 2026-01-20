#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant App (Add-on): Cloudflared
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

bashio::log.info "Connecting Cloudflare Tunnel..."
bashio::log.debug "cloudflared tunnel ${options[*]}"
exec cloudflared tunnel "${options[@]}"
