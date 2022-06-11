#!/command/with-contenv bashio

# Map HomeAssistant log levels to Cloudflared
if bashio::config.exists 'log_level' ; then
    case $(bashio::config 'log_level') in
        "trace") cloudflared_log="info";;
        "debug") cloudflared_log="info";;
        "info") cloudflared_log="info";;
        "notice") cloudflared_log="info";;
        "warning") cloudflared_log="warn";;
        "error") cloudflared_log="error";;
        "fatal") cloudflared_log="fatal";;
    esac
else
    cloudflared_log="info"
fi

# Write log level to S6 environment 
printf "%s" "${cloudflared_log}" > /var/run/s6/container_environment/CLOUDFLARED_LOG
bashio::log.debug "Cloudflared log level set to \"${cloudflared_log}\""