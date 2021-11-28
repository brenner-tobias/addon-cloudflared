#!/bin/sh
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Container build of Cloudflared
# ==============================================================================

# Machine architecture as first parameter
arch=$1

# Cloudflared Release to build from
cloudfalredRelease="2021.11.0"

# Adapt the architecture to the cloudflared specific names if needed
# see HA Archs: https://developers.home-assistant.io/docs/add-ons/configuration/#:~:text=the%20add%2Don.-,arch,-list
# see Cloudflared Archs https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation
case $arch in
    "aarch64")
        arch="arm64"
    ;;

    "armhf")
        arch="arm"
    ;;

    "armv7")
        arch="arm"
    ;;

    "i386")
        arch="arm64"
    ;;
esac

# Download the needed cloudflared version
curl -L -o /opt/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${cloudfalredRelease}/cloudflared-linux-${arch}"

# Make the downloaded file executeable
chmod +x /opt/cloudflared