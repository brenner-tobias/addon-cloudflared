#!/usr/bin/with-contenv bashio

# Map HomeAssistant log levels to Cloudflared
if bashio::config.exists 'log_level' ; then
    case $(bashio::config 'log_level') in
        "trace") cloudflared_log="debug";;
        "debug") cloudflared_log="debug";;
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
printf "${cloudflared_log}" > /var/run/s6/container_environment/cloudflared_log
bashio::log.debug "Cloudflared log level set to \"${cloudflared_log}\""