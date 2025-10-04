#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Configures the Cloudflare Tunnel and creates the needed DNS entry under the
# given hostname(s)
# ==============================================================================

# ------------------------------------------------------------------------------
# Validates configuration and sets global variables used in the script
# ------------------------------------------------------------------------------
validateConfigAndSetVars() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Validating add-on configuration..."

    local validHostnameRegex="^(([a-z0-9äöüß]|[a-z0-9äöüß][a-z0-9äöüß\-]*[a-z0-9äöüß])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$"

    # Check for minimum configuration options
    if
        bashio::config.is_empty 'tunnel_token' &&
            bashio::config.is_empty 'external_hostname' &&
            bashio::config.is_empty 'additional_hosts' &&
            bashio::config.is_empty 'catch_all_service' &&
            bashio::config.is_empty 'nginx_proxy_manager'
    then
        bashio::exit.nok "Cannot run without tunnel_token, external_hostname, additional_hosts, catch_all_service or nginx_proxy_manager. Please set at least one of these add-on options."
    fi

    # Set and validate 'external_hostname'
    if bashio::config.has_value 'external_hostname'; then
        external_hostname="$(bashio::config 'external_hostname')"
        if ! [[ ${external_hostname} =~ ${validHostnameRegex} ]]; then
            bashio::exit.nok "'${external_hostname}' is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') and only use lowercase characters in the 'external_hostname'."
        fi
    else
        external_hostname=""
    fi
    bashio::log.debug "external_hostname: ${external_hostname}"

    # Set and validate 'use_builtin_proxy'
    if bashio::config.true 'use_builtin_proxy'; then
        use_builtin_proxy=true
        # Check if 'use_builtin_proxy' is true and 'external_hostname' is empty
        if bashio::var.is_empty "${external_hostname}"; then
            bashio::exit.nok "'use_builtin_proxy' can only be used if 'external_hostname' is set. Please set 'external_hostname' or disable 'use_builtin_proxy'"
        fi
    else
        use_builtin_proxy=false
    fi
    bashio::log.debug "use_builtin_proxy: ${use_builtin_proxy}"

    # Set and validate additional_hosts
    if bashio::config.has_value 'additional_hosts'; then
        additional_hosts=$(bashio::jq "$(bashio::addon.config)" ".additional_hosts[]")
        readarray -t additional_hosts <<<"${additional_hosts}"

        local additional_host
        local hostname
        local service
        for additional_host in "${additional_hosts[@]}"; do
            bashio::log.debug "Checking host ${additional_host}..."
            hostname=$(bashio::jq "${additional_host}" ".hostname")
            service=$(bashio::jq "${additional_host}" ".service")
            if bashio::var.is_empty "${hostname}" && bashio::var.is_empty "${service}"; then
                bashio::exit.nok "'hostname' and 'service' in 'additional_hosts' are empty, please enter a valid String"
            fi
            if bashio::var.is_empty "${hostname}"; then
                bashio::exit.nok "'hostname' in 'additional_hosts' for service ${service} is empty, please enter a valid String"
            fi
            # Check if hostname of 'additional_host' includes a valid hostname
            if ! [[ ${hostname} =~ ${validHostnameRegex} ]]; then
                bashio::exit.nok "'${hostname}' in 'additional_hosts' is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') and only use lowercase characters in the 'hostname'."
            fi
            if bashio::var.is_empty "${service}"; then
                bashio::exit.nok "'service' in 'additional_hosts' for hostname ${hostname} is empty, please enter a valid String"
            fi
        done
    else
        additional_hosts=()
    fi

    # Check 'catch_all_service'
    if bashio::config.exists 'catch_all_service' && bashio::config.is_empty 'catch_all_service'; then
        bashio::exit.nok "'catch_all_service' is defined as an empty String. Please remove 'catch_all_service' from the configuration or enter a valid String"
    fi

    # Check if 'catch_all_service' and 'nginx_proxy_manager' are both included in config.
    if bashio::config.has_value 'catch_all_service' && bashio::config.true 'nginx_proxy_manager'; then
        bashio::exit.nok "The config includes 'nginx_proxy_manager' and 'catch_all_service'. Please delete one of them since they are mutually exclusive"
    fi

    # Set other global variables
    tunnel_uuid=""
    data_path="/data"

    bashio::log.debug "Checking Home Assistant port and if SSL is used..."
    local ha_config_file="/homeassistant/configuration.yaml"
    local ha_port="8123"
    local ha_ssl="false"
    if yq . "${ha_config_file}" >/dev/null; then
      # https://www.home-assistant.io/integrations/http/#http-configuration-variables
      ha_port=$(yq ".http.server_port // ${ha_port}" "${ha_config_file}")
      ha_ssl=$(yq '.http | (has("ssl_certificate") and has("ssl_key"))' "${ha_config_file}")
    else
      bashio::log.warning "Unable to parse Home Assistant configuration file at ${ha_config_file}, assuming port ${ha_port} and no SSL"
    fi
    bashio::log.debug "ha_port: ${ha_port}"
    bashio::log.debug "ha_ssl: ${ha_ssl}"

    local ha_protocol
    if bashio::var.true "${ha_ssl}"; then
        ha_protocol="https"
    else
        ha_protocol="http"
    fi
    bashio::log.debug "ha_protocol: ${ha_protocol}"

    ha_url="${ha_protocol}://homeassistant:${ha_port}"
    bashio::log.debug "ha_url: ${ha_url}"

    if bashio::config.has_value 'tunnel_name'; then
        tunnel_name="$(bashio::config 'tunnel_name')"
    else
        tunnel_name="homeassistant"
    fi
    bashio::log.debug "tunnel_name: ${tunnel_name}"
}

# ------------------------------------------------------------------------------
# Checks if Cloudflare services are reachable
# ------------------------------------------------------------------------------
checkConnectivity() {
    local pass_test=true

    # Check for region1 TCP
    bashio::log.debug "Checking region1.v2.argotunnel.com TCP port 7844"
    if ! nc -z -w 1 region1.v2.argotunnel.com 7844 &>/dev/null; then
        bashio::log.warning "region1.v2.argotunnel.com TCP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region1 UDP
    bashio::log.debug "Checking region1.v2.argotunnel.com UDP port 7844"
    if ! nc -z -u -w 1 region1.v2.argotunnel.com 7844 &>/dev/null; then
        bashio::log.warning "region1.v2.argotunnel.com UDP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region2 TCP
    bashio::log.debug "Checking region2.v2.argotunnel.com TCP port 7844"
    if ! nc -z -w 1 region2.v2.argotunnel.com 7844 &>/dev/null; then
        bashio::log.warning "region2.v2.argotunnel.com TCP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region2 UDP
    bashio::log.debug "Checking region2.v2.argotunnel.com UDP port 7844"
    if ! nc -z -u -w 1 region2.v2.argotunnel.com 7844 &>/dev/null; then
        bashio::log.warning "region2.v2.argotunnel.com UDP port 7844 not reachable"
        pass_test=false
    fi

    # Check for API TCP
    bashio::log.debug "Checking api.cloudflare.com TCP port 443"
    if ! nc -z -w 1 api.cloudflare.com 443 &>/dev/null; then
        bashio::log.warning "api.cloudflare.com TCP port 443 not reachable"
        pass_test=false
    fi

    if bashio::var.false ${pass_test}; then
        bashio::log.warning "Some necessary services may not be reachable from your host."
        bashio::log.warning "Please review lines above and check your firewall/router settings."
    fi

}

# ------------------------------------------------------------------------------
# Check if Cloudflared certificate (authorization) is available
# ------------------------------------------------------------------------------
hasCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking for existing certificate..."
    if bashio::fs.file_exists "${data_path}/cert.pem"; then
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
    if ! bashio::fs.file_exists "${data_path}/tunnel.json"; then
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
    cloudflared --origincert="${data_path}/cert.pem" --cred-file="${data_path}/tunnel.json" tunnel --loglevel "${CLOUDFLARED_LOG}" create "${tunnel_name}" ||
        bashio::exit.nok "Failed to create tunnel.
    Please check the Cloudflare Zero Trust Dashboard for an existing tunnel with the name ${tunnel_name} and delete it:
    Visit https://one.dash.cloudflare.com, then click on Networks -> Tunnels"

    bashio::log.debug "Created new tunnel: $(cat "${data_path}"/tunnel.json)"

    hasTunnel || bashio::exit.nok "Failed to create tunnel"
}

# ------------------------------------------------------------------------------
# Create Cloudflare config with variables from HA-Add-on-Config
# ------------------------------------------------------------------------------
createConfig() {
    local config
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating config file..."

    # Add tunnel information
    config=$(bashio::jq "{\"tunnel\":\"${tunnel_uuid}\"}" ".")
    config=$(bashio::jq "${config}" ".\"credentials-file\" += \"${data_path}/tunnel.json\"")

    # Add Service for Home Assistant if 'external_hostname' is set
    if bashio::var.has_value "${external_hostname}"; then
        if bashio::var.true "${use_builtin_proxy}"; then
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"https://caddy.localhost\"}]")
        else
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"${ha_url}\"}]")
        fi
    fi

    # Check for configured additional hosts and add them if existing
    local additional_host
    local disableChunkedEncoding
    for additional_host in "${additional_hosts[@]}"; do
        # Make Cloudflared always reach the Caddy proxy if enabled
        if bashio::var.true "${use_builtin_proxy}"; then
            additional_host=$(bashio::jq "${additional_host}" '.service = "https://caddy.localhost"')
        elif bashio::var.true "$(bashio::jq "${additional_host}" ".internalOnly")"; then
            # Avoid accidental exposure of internal services when not using Caddy
            continue
        fi

        # internalOnly is only relevant for Caddy, not for Cloudflared
        additional_host=$(bashio::jq "${additional_host}" "del(.internalOnly)")

        # Check for originRequest configuration option: disableChunkedEncoding
        disableChunkedEncoding=$(bashio::jq "${additional_host}" ". | select(.disableChunkedEncoding != null) | .disableChunkedEncoding ")
        if ! [[ ${disableChunkedEncoding} == "" ]]; then
            additional_host=$(bashio::jq "${additional_host}" "del(.disableChunkedEncoding)")
            additional_host=$(bashio::jq "${additional_host}" ".originRequest += {\"disableChunkedEncoding\": ${disableChunkedEncoding}}")
        fi

        # Add additional_host config to ingress config
        config=$(bashio::jq "${config}" ".ingress[.ingress | length ] |= . + ${additional_host}")
    done

    # Check if NGINX Proxy Manager is used to finalize configuration
    if bashio::config.true 'nginx_proxy_manager'; then

        bashio::log.warning "Runing with Nginxproxymanager support, make sure the add-on is installed and running."
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http://a0d7b954-nginxproxymanager\"}]")
    else

        # Check if catch all service is defined
        if bashio::config.has_value 'catch_all_service'; then

            bashio::log.info "Runing with Catch all Service"
            # Setting catch all service to defined URL
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"$(bashio::config 'catch_all_service')\"}]")
        else
            # Finalize config without NPM support and catch all service, sending all other requests to HTTP:404
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http_status:404\"}]")
        fi
    fi

    if bashio::var.true "${use_builtin_proxy}"; then
        # With Caddy we can avoid noTLSVerify and also can use HTTP/2
        # Even HTTP/3 is possible, but Cloudflared does not support it yet:
        # https://developers.cloudflare.com/speed/optimization/protocol/http3/
        config=$(bashio::jq "${config}" '(.ingress[] | select(.service == "https://caddy.localhost") | .originRequest) += {"caPool": "/data/caddy/pki/authorities/local/root.crt", "http2Origin": true}')
    else
        # Deactivate TLS verification for all services
        config=$(bashio::jq "${config}" ".ingress[].originRequest += {\"noTLSVerify\": true}")
    fi

    # Write content of config variable to config file for cloudflared
    local default_config="/tmp/config.json"
    bashio::jq "${config}" "." >"${default_config}"

    # Validate config using cloudflared
    bashio::log.info "Validating config file..."
    bashio::log.debug "Validating created config file: $(bashio::jq "${default_config}" ".")"
    cloudflared tunnel --config="${default_config}" --loglevel "${CLOUDFLARED_LOG}" ingress validate ||
        bashio::exit.nok "Validation of Config failed, please check the logs above."

    bashio::log.debug "Sucessfully created config file: $(bashio::jq "${default_config}" ".")"
}

# ------------------------------------------------------------------------------
# Create cloudflare DNS entry for external hostname and additional hosts
# ------------------------------------------------------------------------------
createDNS() {
    bashio::log.trace "${FUNCNAME[0]}"

    # Create DNS entry for external hostname of Home Assistant if 'external_hostname' is set
    if bashio::config.has_value 'external_hostname'; then
        bashio::log.info "Creating DNS entry ${external_hostname}..."
        cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${external_hostname}" ||
            bashio::exit.nok "Failed to create DNS entry ${external_hostname}."
    fi

    # Check for configured additional hosts and create DNS entries for them if existing
    local additional_host
    local hostname
    for additional_host in "${additional_hosts[@]}"; do
        if bashio::var.false "${use_builtin_proxy}" && bashio::var.true "$(bashio::jq "${additional_host}" ".internalOnly")"; then
            # Avoid accidental exposure of internal services when not using Caddy
            continue
        fi

        hostname=$(bashio::jq "${additional_host}" ".hostname")
        bashio::log.info "Creating DNS entry ${hostname}..."
        cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${hostname}" ||
            bashio::exit.nok "Failed to create DNS entry ${hostname}."
    done
}

# ------------------------------------------------------------------------------
# Set Cloudflared log level
# ------------------------------------------------------------------------------
setCloudflaredLogLevel() {

    # Set cloudflared log to "info" as default
    CLOUDFLARED_LOG="info"

    # Check if user wishes to change log severity
    if bashio::config.has_value 'run_parameters'; then
        bashio::log.trace "bashio::config.has_value 'run_parameters'"
        for run_parameter in $(bashio::config 'run_parameters'); do
            bashio::log.trace "Checking run_parameter: ${run_parameter}"
            if [[ $run_parameter == --loglevel=* ]]; then
                CLOUDFLARED_LOG=${run_parameter#*=}
                bashio::log.trace "Setting CLOUDFLARED_LOG to: ${run_parameter#*=}"
            fi
        done
    fi

    bashio::log.debug "Cloudflared log level set to \"${CLOUDFLARED_LOG}\""

}

# ------------------------------------------------------------------------------
# Configure the built-in Caddy proxy
# ------------------------------------------------------------------------------
configureCaddy() {
    bashio::log.trace "${FUNCNAME[0]}"

    bashio::log.info "Configuring built-in Caddy proxy..."

    if [[ "$(bashio::addon.port "443/tcp")" == "443" ]]; then
        bashio::log.info "Internal port 443/tcp is exposed to host port 443, enabling automatic HTTPS for local proxy"
        local auto_https=true
    else
        bashio::log.info "Internal port 443/tcp is not exposed to host port 443, not enabling automatic HTTPS for local proxy"
        local auto_https=false
    fi

    bashio::log.info "Generating Caddyfile..."
    additional_hosts_json=$(bashio::jq "$(bashio::addon.config)" ".additional_hosts")
    tempio_input=$(
        jq -n \
            --argjson auto_https "${auto_https}" \
            --arg ha_external_hostname "${external_hostname}" \
            --arg ha_service_url "${ha_url}" \
            --argjson additional_hosts "${additional_hosts_json}" \
            '{auto_https: $auto_https, ha_external_hostname: $ha_external_hostname, ha_service_url: $ha_service_url, additional_hosts: $additional_hosts}'
    )
    bashio::log.debug "Tempio input for generating Caddyfile:\n${tempio_input}"
    tempio -template /etc/caddy/Caddyfile.gtpl -out /etc/caddy/Caddyfile <<<"${tempio_input}"
    bashio::log.debug "Generated Caddyfile:\n$(cat /etc/caddy/Caddyfile)"

    bashio::log.info "Validating Caddyfile..."
    caddy fmt --overwrite --config /etc/caddy/Caddyfile || bashio::exit.nok "Caddyfile formatting failed, please check the logs above."
    caddy validate --config /etc/caddy/Caddyfile || bashio::exit.nok "Caddyfile validation failed, please check the logs above."

    bashio::log.info "Adding host entry for communication between Cloudflared and Caddy..."
    echo "127.0.0.1 caddy.localhost" | tee -a /etc/hosts
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
    bashio::log.trace "${FUNCNAME[0]}"

    setCloudflaredLogLevel

    # Run service with tunnel token without creating config
    if bashio::config.has_value 'tunnel_token'; then
        bashio::log.info "Using Cloudflare Remote Management Tunnel"
        bashio::log.info "All add-on configuration options except tunnel_token will be ignored."
        bashio::exit.ok
    fi

    # Run connectivity checks if debug mode activated
    if bashio::debug; then
        bashio::log.debug "Checking connectivity to Cloudflare"
        checkConnectivity
    fi

    validateConfigAndSetVars

    if bashio::var.true "${use_builtin_proxy}"; then
        configureCaddy
    fi

    if ! hasCertificate; then
        createCertificate
    fi

    if ! hasTunnel; then
        createTunnel
    fi

    createConfig

    createDNS

    bashio::log.info "Finished setting up the Cloudflare Tunnel"
}
main "$@"
