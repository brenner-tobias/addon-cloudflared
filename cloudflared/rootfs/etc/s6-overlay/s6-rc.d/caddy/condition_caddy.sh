#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Decides whether to run Caddy based on the use_builtin_proxy setting or not.
# ==============================================================================

if bashio::config.true 'use_builtin_proxy'; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/caddy
fi
