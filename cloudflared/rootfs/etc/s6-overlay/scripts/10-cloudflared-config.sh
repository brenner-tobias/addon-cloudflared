#!/command/with-contenv bashio
# shellcheck disable=SC2207
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Configures the Cloudflare Tunnel and creates the needed DNS entry under the
# given hostname(s)
# ==============================================================================

# ------------------------------------------------------------------------------
# Checks for legacy options and removes them
# ------------------------------------------------------------------------------
checkLegacyOptions() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking config for legacy options..."

    if bashio::config.has_value 'data_folder' ; then
        bashio::log.warning "Your config contains the option 'data_folder'"
        bashio::log.warning "This option is not supported anymore"
        bashio::addon.option 'data_folder'
        bashio::log.warning "The option 'data_folder' was removed from your add-on configuration"
    fi

    if bashio::config.has_value 'custom_config' ; then
        bashio::log.warning "Your config contains the option 'custom_config'"
        bashio::log.warning "This option is not supported anymore"
        bashio::log.warning "Please migrate to a Cloudflare Managed Tunnel for extended funtionality"
        bashio::addon.option 'custom_config'
        bashio::log.warning "The option 'custom_config' was removed from your add-on configuration"
    fi
    
    if bashio::config.has_value 'warp_enable' ; then
        bashio::log.warning "Your config contains the option 'warp_enable'"
        bashio::log.warning "This option is not supported anymore"
        bashio::log.warning "Please migrate to a Cloudflare Managed Tunnel for extended funtionality"
        bashio::addon.option 'warp_enable'
        bashio::log.warning "The option 'warp_enable' was removed from your add-on configuration"
    fi

    if bashio::config.has_value 'warp_routes' ; then
        bashio::log.warning "Your config contains the option 'warp_routes'"
        bashio::log.warning "This option is not supported anymore"
        bashio::log.warning "Please migrate to a Cloudflare Managed Tunnel for extended funtionality"
        bashio::addon.option 'warp_routes'
        bashio::log.warning "The option 'warp_routes' was removed from your add-on configuration"
    fi

    if bashio::config.has_value 'warp_reset' ; then
        bashio::log.warning "Your config contains the option 'warp_reset'"
        bashio::log.warning "This option is not supported anymore"
        bashio::log.warning "Please migrate to a Cloudflare Managed Tunnel for extended funtionality"
        bashio::addon.option 'warp_reset'
        bashio::log.warning "The option 'warp_reset' was removed from your add-on configuration"
    fi
}

# ------------------------------------------------------------------------------
# Checks if the config is valid
# ------------------------------------------------------------------------------
checkConfig() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking add-on config..."

    local validHostnameRegex="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"

    # Check for minimum configuration options
    if bashio::config.is_empty 'external_hostname' && bashio::config.is_empty 'additional_hosts' && 
        bashio::config.is_empty 'catch_all_service' && bashio::config.is_empty 'nginx_proxy_manager';
    then
        bashio::exit.nok "Cannot run without tunnel_token, external_hostname, additional_hosts, catch_all_service or nginx_proxy_manager. Please set at least one of these add-on options."
    fi

    # Check if 'external_hostname' includes a valid hostname
    if bashio::config.has_value 'external_hostname' ; then
        if ! [[ $(bashio::config 'external_hostname') =~ ${validHostnameRegex} ]] ; then
            bashio::exit.nok "'$(bashio::config 'external_hostname')' is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') in the 'external_hostname'."
        fi
    fi

    # Check if all defined 'additional_hosts' have non-empty strings as hostname and service
    if bashio::config.has_value 'additional_hosts' ; then
        local hostname
        local service
        for additional_host in $(bashio::jq "/data/options.json" ".additional_hosts[]"); do
            bashio::log.debug "Checking host ${additional_host}..."
            hostname=$(bashio::jq "${additional_host}" ".hostname")
            service=$(bashio::jq "${additional_host}" ".service")
            if bashio::var.is_empty "${hostname}" && bashio::var.is_empty "${service}"; then
                bashio::exit.nok "'hostname' and 'service' in 'additional_hosts' are empty, please enter a valid String"
            fi
            if bashio::var.is_empty "${hostname}" ; then
                bashio::exit.nok "'hostname' in 'additional_hosts' for service ${service} is empty, please enter a valid String"
            fi
            # Check if hostname of 'additional_host' includes a valid hostname
            if ! [[ ${hostname} =~ ${validHostnameRegex} ]] ; then
                bashio::exit.nok "'${hostname}' in 'additional_hosts' is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') in the 'hostname'."
            fi
            if bashio::var.is_empty "${service}" ; then
                bashio::exit.nok "'service' in 'additional_hosts' for hostname ${hostname} is empty, please enter a valid String"
            fi
        done
    fi

    # Check if 'catch_all_service' is included in config with an empty String
    if bashio::config.exists 'catch_all_service' && bashio::config.is_empty 'catch_all_service' ; then
        bashio::exit.nok "'catch_all_service' is defined as an empty String. Please remove 'catch_all_service' from the configuration or enter a valid String"
    fi

    # Check if 'catch_all_service' and 'nginx_proxy_manager' are both included in config.
    if bashio::config.has_value 'catch_all_service' && bashio::config.true 'nginx_proxy_manager' ; then
        bashio::exit.nok "The config includes 'nginx_proxy_manager' and 'catch_all_service'. Please delete one of them since they are mutually exclusive"
    fi
}

# ------------------------------------------------------------------------------
# Check if Cloudflared certificate (authorization) is available
# ------------------------------------------------------------------------------
hasCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking for existing certificate..."
    if bashio::fs.file_exists "${data_path}/cert.pem" ; then
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
    bashio::log.notice
    bashio::log.notice "Please follow the Cloudflare Auth-Steps:"
    bashio::log.notice
    cloudflared tunnel login

    bashio::log.info "Authentication successfull, moving auth file to the '${data_path}' folder"

    mv /root/.cloudflared/cert.pem "${data_path}/cert.pem" || bashio::exit.nok "Failed to move auth file"

    hasCertificate || bashio::exit.nok "Failed to create certificate"
}

# ------------------------------------------------------------------------------
# Check if Cloudflare Tunnel is existing
# ------------------------------------------------------------------------------
hasTunnel() {
    bashio::log.trace "${FUNCNAME[0]}:"
    bashio::log.info "Checking for existing tunnel..."

    # Check if tunnel file(s) exist
    if ! bashio::fs.file_exists "${data_path}/tunnel.json" ; then
        bashio::log.notice "No tunnel file found"
        return "${__BASHIO_EXIT_NOK}"
    fi

    # Get tunnel UUID from JSON
    tunnel_uuid="$(bashio::jq "${data_path}/tunnel.json" ".TunnelID")"

    bashio::log.info "Existing tunnel with ID ${tunnel_uuid} found"

    # Get tunnel name from Cloudflare API by tunnel id and chek if it matches config value
    bashio::log.info "Checking if existing tunnel matches name given in config"
    local existing_tunnel_name
    existing_tunnel_name=$(cloudflared --origincert="${data_path}/cert.pem" tunnel \
        list --output="json" --id="${tunnel_uuid}" | jq -er '.[].name')
    bashio::log.debug "Existing Cloudflare Tunnel name: $existing_tunnel_name"
    if [[ $tunnel_name != "$existing_tunnel_name" ]]; then
        bashio::log.error "Existing Cloudflare Tunnel name does not match add-on config."
        bashio::log.error "---------------------------------------"
        bashio::log.error "Add-on Configuration tunnel name: ${tunnel_name}"
        bashio::log.error "Tunnel credentials file tunnel name: ${existing_tunnel_name}"
        bashio::log.error "---------------------------------------"
        bashio::log.error "Align add-on configuration to match existing tunnel credential file"
        bashio::log.error "or re-install the add-on."
        bashio::exit.nok
    fi
    bashio::log.info "Existing Cloudflare Tunnel name matches config, proceeding with existing tunnel file"

    return "${__BASHIO_EXIT_OK}"
}

# ------------------------------------------------------------------------------
# Create Cloudflare Tunnel with name from HA-Add-on-Config
# ------------------------------------------------------------------------------
createTunnel() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new tunnel..."
    cloudflared --origincert="${data_path}/cert.pem" --cred-file="${data_path}/tunnel.json" tunnel --loglevel "${CLOUDFLARED_LOG}" create "${tunnel_name}" \
    || bashio::exit.nok "Failed to create tunnel.
    Please check the Cloudflare Teams Dashboard for an existing tunnel with the name ${tunnel_name} and delete it:
    https://dash.teams.cloudflare.com/ Access / Tunnels"

    bashio::log.debug "Created new tunnel: $(cat "${data_path}"/tunnel.json)"

    hasTunnel || bashio::exit.nok "Failed to create tunnel"
}

# ------------------------------------------------------------------------------
# Create Cloudflare config with variables from HA-Add-on-Config
# ------------------------------------------------------------------------------
createConfig() {
    local ha_service_protocol
    local config
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating config file..."

    # Add tunnel information
    config=$(bashio::jq "{\"tunnel\":\"${tunnel_uuid}\"}" ".")
    config=$(bashio::jq "${config}" ".\"credentials-file\" += \"${data_path}/tunnel.json\"")

    bashio::log.debug "Checking if SSL is used..."
    if bashio::var.true "$(bashio::core.ssl)" ; then
        ha_service_protocol="https"
    else
        ha_service_protocol="http"
    fi
    bashio::log.debug "ha_service_protocol: ${ha_service_protocol}"

    if bashio::var.is_empty "${ha_service_protocol}" ; then
        bashio::exit.nok "Error checking if SSL is enabled"
    fi

    # Add Service for Home Assistant if 'external_hostname' is set
    if bashio::config.has_value 'external_hostname' ; then
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"${ha_service_protocol}://homeassistant:$(bashio::core.port)\"}]")
    fi

    # Check for configured additional hosts and add them if existing
    if bashio::config.has_value 'additional_hosts' ; then
        # Loop additional_hosts to create json config
        while read -r additional_host; do
            # Check for originRequest configuration option: disableChunkedEncoding
            disableChunkedEncoding=$(bashio::jq "${additional_host}" ". | select(.disableChunkedEncoding != null) | .disableChunkedEncoding ")
            if ! [[ ${disableChunkedEncoding} == "" ]]  ; then
                additional_host=$(bashio::jq "${additional_host}" "del(.disableChunkedEncoding)")
                additional_host=$(bashio::jq "${additional_host}" ".originRequest += {\"disableChunkedEncoding\": ${disableChunkedEncoding}}")
            fi
            # Add additional_host config to ingress config
            config=$(bashio::jq "${config}" ".ingress[.ingress | length ] |= . + ${additional_host}")
        done <<< "$(jq -c '.additional_hosts[]' /data/options.json )"
    fi

    # Check if NGINX Proxy Manager is used to finalize configuration
    if bashio::config.true 'nginx_proxy_manager' ; then

        bashio::log.warning "Runing with Nginxproxymanager support, make sure the add-on is installed and running."
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http://a0d7b954-nginxproxymanager:80\"}]")
    else

        # Check if catch all service is defined
        if bashio::config.has_value 'catch_all_service' ; then

            bashio::log.info "Runing with Catch all Service"
            # Setting catch all service to defined URL
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"$(bashio::config 'catch_all_service')\"}]")
        else
            # Finalize config without NPM support and catch all service, sending all other requests to HTTP:404
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http_status:404\"}]")
        fi
    fi

    # Deactivate TLS verification for all services
    config=$(bashio::jq "${config}" ".ingress[].originRequest += {\"noTLSVerify\": true}")

    # Write content of config variable to config file for cloudflared
    bashio::jq "${config}" "." > "${default_config}"

    # Validate config using cloudflared
    bashio::log.info "Validating config file..."
    bashio::log.debug "Validating created config file: $(bashio::jq "${default_config}" ".")"
    cloudflared tunnel --config="${default_config}" --loglevel "${CLOUDFLARED_LOG}" ingress validate \
    || bashio::exit.nok "Validation of Config failed, please check the logs above."

    bashio::log.debug "Sucessfully created config file: $(bashio::jq "${default_config}" ".")"
}

# ------------------------------------------------------------------------------
# Create cloudflare DNS entry for external hostname and additional hosts
# ------------------------------------------------------------------------------
createDNS() {
    bashio::log.trace "${FUNCNAME[0]}"

    # Create DNS entry for external hostname of Home Assistant if 'external_hostname' is set
    if bashio::config.has_value 'external_hostname' ; then
        bashio::log.info "Creating new DNS entry ${external_hostname}..."
        cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${external_hostname}" \
        || bashio::exit.nok "Failed to create DNS entry ${external_hostname}."
    fi

    # Check for configured additional hosts and create DNS entries for them if existing
    if bashio::config.has_value 'additional_hosts' ; then
        for host in $(bashio::jq "/data/options.json" ".additional_hosts[].hostname"); do
            bashio::log.info "Creating new DNS entry ${host}..."
            if bashio::var.is_empty "${host}" ; then
                bashio::exit.nok "'hostname' in 'additional_hosts' is empty, please enter a valid String"
            fi
            cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${host}" \
            || bashio::exit.nok "Failed to create DNS entry ${host}."
        done
    fi
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
declare default_config=/tmp/config.json
external_hostname=""
tunnel_name="homeassistant"
tunnel_uuid=""
data_path="/data"

main() {
    bashio::log.trace "${FUNCNAME[0]}"

    checkLegacyOptions

    # Run service with tunnel token without creating config
    if bashio::config.has_value 'tunnel_token'; then
        bashio::log.info ""
        bashio::log.info "Using Cloudflare Remote Management Tunnel"
        bashio::log.info "All add-on configuration options except tunnel_token"
        bashio::log.info "will be ignored."
        bashio::log.info ""
        bashio::exit.ok
    fi

    checkConfig

    if bashio::config.has_value 'tunnel_name' ; then
        tunnel_name="$(bashio::config 'tunnel_name')"
    fi

    external_hostname="$(bashio::config 'external_hostname')"

    if ! hasCertificate ; then
        createCertificate
    fi

    if ! hasTunnel ; then
        createTunnel
    fi

    createConfig

    createDNS

    bashio::log.info "Finished setting-up the Cloudflare Tunnel"
}
main "$@"
