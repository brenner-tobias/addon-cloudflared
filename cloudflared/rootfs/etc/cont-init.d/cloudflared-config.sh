#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Creates a Cloudflared tunnel to a given Cloudflare Teams project and creates
# the needed DNS entry under the given hostname
# ==============================================================================

# ------------------------------------------------------------------------------
# Delete all Cloudflared config files
# ------------------------------------------------------------------------------
resetCloudflareFiles() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.warning "Deleting all existing Cloudflared config files..."

    if bashio::fs.file_exists "/data/cert.pem" ; then
        bashio::log.debug "Deleting certificate file"
        rm -f /data/cert.pem || bashio::exit.nok "Failed to delete certificate file"
    fi

    if bashio::fs.file_exists "/data/tunnel.json" ; then
        bashio::log.debug "Deleting tunnel file"
        rm -f /data/tunnel.json || bashio::exit.nok "Failed to delete tunnel file"
    fi

    if bashio::fs.file_exists "/data/config.yml" ; then
        bashio::log.debug "Deleting config file"
        rm -f /data/config.yml || bashio::exit.nok "Failed to delete config file"
    fi

    if bashio::fs.file_exists "/data/cert.pem" \
        || bashio::fs.file_exists "/data/tunnel.json" \
        || bashio::fs.file_exists "/data/config.yml";
    then
        bashio::exit.nok "Failed to delete cloudflared files"
    fi

    bashio::log.info "Succesfully deleted cloudflared files"

    bashio::log.debug "Removing 'reset_cloudflared_files' option from add-on config"
    bashio::addon.option 'reset_cloudflared_files'
}

# ------------------------------------------------------------------------------
# Check if Cloudflared certificate (authorization) is available
# ------------------------------------------------------------------------------
hasCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking for existing certificate..."
    if bashio::fs.file_exists "/data/cert.pem" ; then
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
    cloudflared tunnel login

    bashio::log.green "Authentication successfull, moving auth file to config folder"

    mv /root/.cloudflared/cert.pem /data/cert.pem || bashio::exit.nok "Failed to move auth file"

    hasCertificate || bashio::exit.nok "Failed to create certificate"
}

# ------------------------------------------------------------------------------
# Check if Cloudflared tunnel is existing
# ------------------------------------------------------------------------------
hasTunnel() {
    bashio::log.trace "${FUNCNAME[0]}:"
    bashio::log.info "Checking for existing tunnel..."

    # Check if tunnel file(s) exist
    if ! bashio::fs.file_exists "/data/tunnel.json" ; then
        bashio::log.notice "No tunnel file found"
        return "${__BASHIO_EXIT_NOK}"
    fi

    # Get tunnel UUID from JSON
    tunnel_uuid="$(bashio::jq "/data/tunnel.json" .TunnelID)"

    bashio::log.info "Existing tunnel with ID ${tunnel_uuid} found"

    # Check if tunnel name in file matches config value
    bashio::log.info "Checking if existing tunnel matches name given in config"
    local tunnel_name_from_file
    tunnel_name_from_file="$(bashio::jq "/data/tunnel.json" .TunnelName)"
    bashio::log.debug "Tunnnel name read from file: $tunnel_name_from_file"
    if [[ $tunnel_name != "$tunnel_name_from_file" ]]; then
        bashio::log.warning "Tunnel name in file does not match config, removing tunnel file"
        rm -f /data/tunnel.json  || bashio::exit.nok "Failed to remove tunnel file"
        return "${__BASHIO_EXIT_NOK}"
    fi
    bashio::log.info "Tunnnel name read from file matches config, proceeding with existing tunnel file"

    return "${__BASHIO_EXIT_OK}"
}

# ------------------------------------------------------------------------------
# Create cloudflare tunnel with name from HA-Add-on-Config
# ------------------------------------------------------------------------------
createTunnel() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new tunnel..."
    cloudflared --origincert=/data/cert.pem --cred-file=/data/tunnel.json tunnel create "${tunnel_name}" \
    || bashio::exit.nok "Failed to create tunnel.
    Please check the Cloudflare Teams Dashboard for an existing tunnel with the name ${tunnel_name} and delete it:
    https://dash.teams.cloudflare.com/ Access / Tunnels"

    bashio::log.debug "Created new tunnel: $(cat /data/tunnel.json)"

    bashio::log.info "Checking for old config"
    if bashio::fs.file_exists "/data/config.yml" ; then
        rm -f /data/config.yml || bashio::exit.nok "Failed to remove old config"
        bashio::log.notice "Old config found and removed"
    else bashio::log.info "No old config found"
    fi

    hasTunnel || bashio::exit.nok "Failed to create tunnel"
}

# ------------------------------------------------------------------------------
# Create cloudflare config with variables from HA-Add-on-Config
# ------------------------------------------------------------------------------
createConfig() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating config file..."

    # Add tunnel information
    yq e -n ".tunnel = ${tunnel_uuid}" > /data/config.yml
    yq e -i '.credentials-file = "/data/tunnel.json"' /data/config.yml

    # Add Service for Home-Assistant
    yq e -i ".ingress = [{\"hostname\": \"${external_ha_hostname}\", \"service\": \"http://homeassistant:$(bashio::core.port)\"}]" /data/config.yml

    # Check for configured additional hosts and add them if existing
    if bashio::config.has_value 'additional_hosts' ; then
        additional_hosts=$(jq -r '.additional_hosts' /data/options.json)
        yq e -i ".ingress += ${additional_hosts}" /data/config.yml
    fi

    # Check if NGINX Proxy Manager is used to finalize configuration
    if bashio::config.true 'nginxproxymanager' ; then

        bashio::log.info "Runing with Nginxproxymanager support"

        local npm_name
        local npm_ip

        # Get full name of Nginxproxymanager from add-on list
        npm_name="$(grep nginxproxymanager <<< "$(bashio::addons.installed)")"

        bashio::log.debug "Nginxproxymanager add-on name: ${npm_name}"

        bashio::log.info "Looking for Nginxproxymanager add-on"

        # Check if Nginxproxymanager is installed and available
        if ! bashio::addons.installed "$npm_name" \
            || ! bashio::addon.available "$npm_name" ; then
            bashio::exit.nok "Nginxproxymanager not found, please install the Add-On or unset
            nginxproxymanager in the add-on config"
        fi

        bashio::log.debug "Nginxproxymanager add-on found: $npm_name"

        npm_ip="$(bashio::addon.ip_address "$npm_name")"

        if bashio::var.is_empty "$npm_ip" ; then
            bashio::exit.nok "Internal IP of Nginxproxymanager not found, please
            install / reset the Add-On"
        fi

        bashio::log.debug "nginxproxymanager IP: ${npm_ip}"

        bashio::log.info "All information about Nginxproxymanager Add-On found"
        yq e -i ".ingress += [{\"service\": \"http://${npm_ip}:80\"}]" /data/config.yml
    else
        # Finalize config without NPM support, sending all other requests to HTTP:404
        yq e -i '.ingress += [{"service": "http_status:404"}]' /data/config.yml
    fi

    bashio::log.info "Sucessfully created config file: $(cat /data/config.yml)"
}

# ------------------------------------------------------------------------------
# Create cloudflare DNS entry for external hostname
# ------------------------------------------------------------------------------
createDNS() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new DNS entry ${external_ha_hostname}..."
    cloudflared --origincert=/data/cert.pem tunnel route dns -f "${tunnel_uuid}" "${external_ha_hostname}" \
    || bashio::exit.nok "Failed to create DNS entry."
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
external_ha_hostname=""
tunnel_name=""
tunnel_uuid="12345"

main() {
    bashio::log.trace "${FUNCNAME[0]}"

    external_ha_hostname="$(bashio::config 'external_ha_hostname')"
    tunnel_name="$(bashio::config 'tunnel_name')"

    #if bashio::config.true 'reset_cloudflared_files' ; then
    #    resetCloudflareFiles
    #fi

    #if ! hasCertificate ; then
    #    createCertificate
    #fi

    #if ! hasTunnel ; then
    #    createTunnel
    #fi

    createConfig

    #createDNS

    bashio::log.info "Finished setting-up the Cloudflare tunnel"
}
main "$@"