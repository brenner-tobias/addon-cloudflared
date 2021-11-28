#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Creates a Cloudflared tunnel to a given Cloudflare Teams project and creates
# the needed DNS entry under the given hostname
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if Cloudflared certificate (authorization) is available
# ------------------------------------------------------------------------------
hasCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking for existing certificate..."
    if bashio::fs.file_exists "/root/.cloudflared/cert.pem" ; then
        bashio::log.info "Existing certificate found"
        return "${__BASHIO_EXIT_OK}"
    fi

    bashio::log.notice "No certificate found"
    return "${__BASHIO_EXIT_NOK}"
}

# ------------------------------------------------------------------------------
# Create cloudflare certificate
# ------------------------------------------------------------------------------
createCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new certificate..."
    bashio::log.notice "Please follow the Cloudflare Auth-Steps:"
    /opt/cloudflared tunnel login

    bashio::log.green "Authentication successfull"

    hasCertificate || bashio::exit.nok "Failed to create certificate"
}

# ------------------------------------------------------------------------------
# Check if Cloudflared tunnel is existing
# ------------------------------------------------------------------------------
hasTunnel() {
    bashio::log.trace "${FUNCNAME[0]}:"
    bashio::log.info "Checking for existing tunnel..."

    tunnel_file="$(ls /root/.cloudflared/*.json)"
    tunnel_file_no_path="${tunnel_file##*/}"
    # Check if tunnel file(s) exist
    if bashio::var.is_empty "${tunnel_file_no_path}" ; then
        bashio::log.notice "No tunnel file found"
        return "${__BASHIO_EXIT_NOK}"
    fi

    # Remove ending of file name to get tunnel UUID
    tunnel_uuid="${tunnel_file_no_path%.*}"

    # Check if multiple tunnel files exist and remove them if so
    if [[ $tunnel_uuid == *"json"* ]]; then
        bashio::log.warning "Multiple tunnel files found, removing them"
        rm -f /root/.cloudflared/*.json
        return "${__BASHIO_EXIT_NOK}"
    fi

    bashio::log.info "Existing tunnel with ID ${tunnel_uuid} found"

    # Check if tunnel name in file matches config value
    bashio::log.info "Checking if existing tunnel matches name given in config"
    local tunnel_name_from_file
    tunnel_name_from_file="$(bashio::jq "/root/.cloudflared/${tunnel_uuid}.json" .TunnelName)"
    bashio::log.debug "Tunnnel name read from file: $tunnel_name_from_file"
    if [[ $tunnel_name != "$tunnel_name_from_file" ]]; then
        bashio::log.warning "Tunnel name in file does not match config, removing tunnel file(s)"
        rm -f /root/.cloudflared/*.json
        return "${__BASHIO_EXIT_NOK}"
    fi
    bashio::log.info "Tunnnel name read from file tunnel matches config, proceeding with existing tunnel file"

    return "${__BASHIO_EXIT_OK}"
}

# ------------------------------------------------------------------------------
# Create cloudflare tunnel with name from HA-Add-on-Config
# ------------------------------------------------------------------------------
createTunnel() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new tunnel..."
    /opt/cloudflared tunnel create "${tunnel_name}" \
    || bashio::exit.nok "Failed to create tunnel.
    Please check the Cloudflare Teams Dashboard for an existing tunnel with the name ${tunnel_name} and delete it:
    https://dash.teams.cloudflare.com/ Access / Tunnels"

    bashio::log.info "Created new tunnel: $(ls /root/.cloudflared/*.json)"

    bashio::log.info "Checking for old config"
    if bashio::fs.file_exists "/root/.cloudflared/config.yml" ; then
        rm -f /root/.cloudflared/config.yml
        bashio::log.notice "Old config found and removed"
    else bashio::log.info "No old config found"
    fi

    hasTunnel || bashio::exit.nok "Failed to create tunnel"
}

# ------------------------------------------------------------------------------
# Create cloudflare config with variables from HA-Add-on-Config and Cloudfalred set-up
# ------------------------------------------------------------------------------
createConfig() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new config file..."
    cat << EOF > /root/.cloudflared/config.yml
        url: http://homeassistant:${internal_ha_port}
        tunnel: ${tunnel_uuid}
        credentials-file: /root/.cloudflared/${tunnel_uuid}.json
EOF
    bashio::log.debug "Sucessfully created config file: $(cat /root/.cloudflared/config.yml)"

    createDNS
}

# ------------------------------------------------------------------------------
# Create cloudflare DNS entry for external hostname
# ------------------------------------------------------------------------------
createDNS() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new DNS entry ${external_hostname}..."
    /opt/cloudflared tunnel route dns "${tunnel_uuid}" "${external_hostname}" \
    || bashio::exit.ok "Failed to create DNS entry. Assuming entry for ${external_hostname} is alredy existing."
    bashio::log.info "Sucessfully creted DNS entry ${external_hostname}"
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
external_hostname=""
internal_ha_port=""
tunnel_name=""
tunnel_uuid=""

main() {
    bashio::log.trace "${FUNCNAME[0]}"

    external_hostname="$(bashio::config 'external_hostname')"
    internal_ha_port="$(bashio::config 'internal_ha_port')"
    tunnel_name="$(bashio::config 'tunnel_name')"

    if ! hasCertificate ; then
        createCertificate
    fi

    if ! hasTunnel ; then
        createTunnel
    fi

    createConfig

    bashio::log.info "Finished setting-up the Cloudflare tunnel"
}
main "$@"