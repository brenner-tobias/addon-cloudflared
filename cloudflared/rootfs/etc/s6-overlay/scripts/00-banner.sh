#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Cloudflared
# Displays a simple add-on banner on startup
# ==============================================================================
if bashio::supervisor.ping; then
    bashio::log.blue \
        '-----------------------------------------------------------'
    bashio::log.blue " Add-on: $(bashio::addon.name)"
    bashio::log.blue " $(bashio::addon.description)"
    bashio::log.blue \
        '-----------------------------------------------------------'

    bashio::log.blue " Add-on version: $(bashio::addon.version)"
    if bashio::var.true "$(bashio::addon.update_available)"; then
        bashio::log.magenta ' There is an update available for this add-on!'
        bashio::log.magenta \
            " Latest add-on version: $(bashio::addon.version_latest)"
        bashio::log.magenta ' Please consider upgrading as soon as possible.'
    else
        bashio::log.green ' You are running the latest version of this add-on.'
    fi

    bashio::log.blue " System: $(bashio::info.operating_system)" \
        " ($(bashio::info.arch) / $(bashio::info.machine))"
    bashio::log.blue " Home Assistant Core: $(bashio::info.homeassistant)"
    bashio::log.blue " Home Assistant Supervisor: $(bashio::info.supervisor)"

if bashio::var.false "$(bashio::supervisor.supported)" ; then
    bashio::log.magenta
    bashio::log.magenta " System setup not officially supported by Home-Assistant."
    bashio::log.magenta " Errors with this add-on may occur."
    bashio::log.magenta " We don't offer support with unsupported setups."
    bashio::log.magenta
fi

if bashio::var.false "$(bashio::supervisor.healthy)" ; then
    bashio::log.magenta
    bashio::log.magenta " System is unhealthy."
    bashio::log.magenta " Errors with this add-on may occur."
    bashio::log.magenta " Before asking for support fix your system health errors."
    bashio::log.magenta
fi

    bashio::log.blue \
        '-----------------------------------------------------------'
    bashio::log.blue \
        ' Please, share the above information when looking for help'
    bashio::log.blue \
        ' or support in, e.g., GitHub or forums.'
    bashio::log.blue \
        '-----------------------------------------------------------'
fi
