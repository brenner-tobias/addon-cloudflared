#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Configures the Cloudflare Tunnel and creates the needed DNS entry under the
# given hostname(s)
# ==============================================================================

# ------------------------------------------------------------------------------
# Checks if the config is valid
# ------------------------------------------------------------------------------
checkConfig() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking add-on config..."

    local validHostnameRegex="^(([a-z0-9äöüß]|[a-z0-9äöüß][a-z0-9äöüß\-]*[a-z0-9äöüß])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$"

    # Check for minimum configuration options
    if
        bashio::config.is_empty 'external_hostname' &&
            bashio::config.is_empty 'additional_hosts' &&
            bashio::config.is_empty 'catch_all_service' &&
            bashio::config.is_empty 'nginx_proxy_manager'
    then
        bashio::exit.nok "Cannot run without tunnel_token, external_hostname, additional_hosts, catch_all_service or nginx_proxy_manager. Please set at least one of these add-on options."
    fi

    # Check if 'external_hostname' includes a valid hostname
    if bashio::config.has_value 'external_hostname'; then
        if ! [[ $(bashio::config 'external_hostname') =~ ${validHostnameRegex} ]]; then
            bashio::exit.nok "'$(bashio::config 'external_hostname')' is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') and only use lowercase characters in the 'external_hostname'."
        fi
    fi

    # Check if all defined 'additional_hosts' have non-empty strings as hostname and service
    if bashio::config.has_value 'additional_hosts'; then
        local hostname
        local service
        for additional_host in $(bashio::jq "/data/options.json" ".additional_hosts[]"); do
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
    fi

    # Check if 'catch_all_service' is included in config with an empty String
    if bashio::config.exists 'catch_all_service' && bashio::config.is_empty 'catch_all_service'; then
        bashio::exit.nok "'catch_all_service' is defined as an empty String. Please remove 'catch_all_service' from the configuration or enter a valid String"
    fi

    # Check if 'catch_all_service' and 'nginx_proxy_manager' are both included in config.
    if bashio::config.has_value 'catch_all_service' && bashio::config.true 'nginx_proxy_manager'; then
        bashio::exit.nok "The config includes 'nginx_proxy_manager' and 'catch_all_service'. Please delete one of them since they are mutually exclusive"
    fi
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
    Visit https://one.dash.cloudflare.com, then click on Access / Tunnels"

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
    if bashio::var.true "$(bashio::core.ssl)"; then
        ha_service_protocol="https"
    else
        ha_service_protocol="http"
    fi
    bashio::log.debug "ha_service_protocol: ${ha_service_protocol}"

    if bashio::var.is_empty "${ha_service_protocol}"; then
        bashio::exit.nok "Error checking if SSL is enabled"
    fi

    ha_service_url="${ha_service_protocol}://homeassistant:$(bashio::core.port)"

    # Add Service for Home Assistant if 'external_hostname' is set
    if bashio::config.has_value 'external_hostname'; then
        if bashio::var.true "${use_builtin_proxy}"; then
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"https://caddy.localhost\"}]")
        else
            config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"${ha_service_url}\"}]")
        fi
    fi

    # Check for configured additional hosts and add them if existing
    if bashio::config.has_value 'additional_hosts'; then
        # Loop additional_hosts to create json config
        while read -r additional_host; do
            # Check for originRequest configuration option: disableChunkedEncoding
            disableChunkedEncoding=$(bashio::jq "${additional_host}" ". | select(.disableChunkedEncoding != null) | .disableChunkedEncoding ")
            if ! [[ ${disableChunkedEncoding} == "" ]]; then
                additional_host=$(bashio::jq "${additional_host}" "del(.disableChunkedEncoding)")
                additional_host=$(bashio::jq "${additional_host}" ".originRequest += {\"disableChunkedEncoding\": ${disableChunkedEncoding}}")
            fi

            # Make Cloudflared always reach the Caddy proxy if enabled
            if bashio::var.true "${use_builtin_proxy}"; then
                additional_host=$(bashio::jq "${additional_host}" '.service = "https://caddy.localhost"')
            elif bashio::var.true "$(bashio::jq "${additional_host}" ".internalOnly")"; then
                bashio::exit.nok "'additional_hosts.internalOnly' is only supported when using the built-in Caddy proxy. Please set 'use_builtin_proxy' to true or remove 'internalOnly' from the additional host configuration."
            fi

            # internalOnly is only for Caddy, not for Cloudflared
            additional_host=$(bashio::jq "${additional_host}" "del(.internalOnly)")

            # Add additional_host config to ingress config
            config=$(bashio::jq "${config}" ".ingress[.ingress | length ] |= . + ${additional_host}")
        done <<<"$(jq -c '.additional_hosts[]' /data/options.json)"
    fi

    if bashio::config.true 'nginx_proxy_manager'; then
        bashio::log.warning "Runing with Nginxproxymanager support, make sure the add-on is installed and running."
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http://a0d7b954-nginxproxymanager\"}]")
    elif bashio::config.has_value 'catch_all_service'; then
        bashio::log.info "Runing with Catch all Service"
        # Setting catch all service to defined URL
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"$(bashio::config 'catch_all_service')\"}]")
    else
        # Finalize config without NPM support and catch all service, sending all other requests to HTTP:404
        config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http_status:404\"}]")
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
    if bashio::config.has_value 'additional_hosts'; then
        for host in $(bashio::jq "/data/options.json" ".additional_hosts[].hostname"); do
            bashio::log.info "Creating DNS entry ${host}..."
            if bashio::var.is_empty "${host}"; then
                bashio::exit.nok "'hostname' in 'additional_hosts' is empty, please enter a valid String"
            fi
            cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${host}" ||
                bashio::exit.nok "Failed to create DNS entry ${host}."
        done
    fi
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

configureCaddy() {
    bashio::log.info "Configuring built-in Caddy proxy..."

    if
        curl -fsSL \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            http://supervisor/addons/self/info |
            jq --exit-status --raw-output '.data.network["443/tcp"]' |
            grep -q '^443$'
    then
        bashio::log.info "Internal port 443/tcp is exposed to host port 443, enabling automatic HTTPS"
        auto_https=true
    else
        bashio::log.info "Internal port 443/tcp is not exposed to host port 443, not enabling automatic HTTPS"
        auto_https=false
    fi

    if bashio::config.true 'nginx_proxy_manager'; then
        bashio::log.warning "Runing with Nginxproxymanager support, make sure the add-on is installed and running."
        catch_all_service="http://a0d7b954-nginxproxymanager:80"
    elif bashio::config.has_value 'catch_all_service'; then
        bashio::log.info "Runing with Catch all Service"
        catch_all_service="$(bashio::config 'catch_all_service')"
    else
        catch_all_service=""
    fi

    bashio::log.info "Generating Caddyfile..."
    tempio_input=$(
        jq -n \
            --arg ha_external_hostname "${external_hostname}" \
            --arg ha_service_url "${ha_service_url}" \
            --arg catch_all_service "${catch_all_service}" \
            --argjson additional_hosts "$(jq -c '.additional_hosts' /data/options.json)" \
            --argjson auto_https "${auto_https}" \
            '{ha_external_hostname: $ha_external_hostname, ha_service_url: $ha_service_url, catch_all_service: $catch_all_service, additional_hosts: $additional_hosts, auto_https: $auto_https}'
    )
    bashio::log.debug "Tempio input:\n${tempio_input}"
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
declare default_config=/tmp/config.json
external_hostname=""
tunnel_name="homeassistant"
tunnel_uuid=""
data_path="/data"

main() {
    bashio::log.trace "${FUNCNAME[0]}"

    setCloudflaredLogLevel

    # Run connectivity checks if debug mode activated
    if bashio::debug; then
        bashio::log.debug "Checking connectivity to Cloudflare"
        checkConnectivity
    fi

    # Run service with tunnel token without creating config
    if bashio::config.has_value 'tunnel_token'; then
        bashio::log.info "Using Cloudflare Remote Management Tunnel"
        bashio::log.info "All add-on configuration options except tunnel_token will be ignored."
        bashio::exit.ok
    fi

    checkConfig

    if bashio::config.has_value 'tunnel_name'; then
        tunnel_name="$(bashio::config 'tunnel_name')"
    fi

    external_hostname="$(bashio::config 'external_hostname')"

    if bashio::config.true 'use_builtin_proxy'; then
        use_builtin_proxy=true
    else
        use_builtin_proxy=false
    fi

    if ! hasCertificate; then
        createCertificate
    fi

    if ! hasTunnel; then
        createTunnel
    fi

    createConfig

    createDNS

    if bashio::var.true "${use_builtin_proxy}"; then
        configureCaddy
    else
        bashio::log.info "Using Cloudflared without built-in Caddy proxy"
        touch /dev/shm/no_built_in_proxy
    fi

    bashio::log.info "Finished setting up the Cloudflare Tunnel"
}
main "$@"
