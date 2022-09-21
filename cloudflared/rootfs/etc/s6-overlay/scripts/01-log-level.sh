#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Cloudflared
# Sets the log level correctly
# ==============================================================================
declare log_level

# Check if the log level configuration option exists
if bashio::config.exists log_level; then

    # Find the matching LOG_LEVEL
    log_level=$(bashio::string.lower "$(bashio::config log_level)")
    case "${log_level}" in
        all)
            log_level="${__BASHIO_LOG_LEVEL_ALL}"
            ;;
        trace)
            log_level="${__BASHIO_LOG_LEVEL_TRACE}"
            ;;
        debug)
            log_level="${__BASHIO_LOG_LEVEL_DEBUG}"
            ;;
        info)
            log_level="${__BASHIO_LOG_LEVEL_INFO}"
            ;;
        notice)
            log_level="${__BASHIO_LOG_LEVEL_NOTICE}"
            ;;
        warning)
            log_level="${__BASHIO_LOG_LEVEL_WARNING}"
            ;;
        error)
            log_level="${__BASHIO_LOG_LEVEL_ERROR}"
            ;;
        fatal)
            log_level="${__BASHIO_LOG_LEVEL_FATAL}"
            ;;
        off)
            log_level="${__BASHIO_LOG_LEVEL_OFF}"
            ;;
        *)
            bashio::exit.nok "Unknown log_level: ${log_level}"
    esac

    # Save determined log level so S6 can pick it up later
    echo "${log_level}" > /var/run/s6/container_environment/LOG_LEVEL
    bashio::log.blue "Log level is set to ${__BASHIO_LOG_LEVELS[$log_level]}"
fi

# Map Home Assistant log levels to Cloudflared
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
