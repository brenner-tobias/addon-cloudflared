#!/bin/sh
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Container build of Cloudflared
# ==============================================================================

# Machine architecture as first parameter
arch=$1

# Dependency releases to build from
cloudfalredRelease="2022.1.0"
yqRelease="v4.16.2"

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
        arch="386"
    ;;
esac

# Download the needed cloudflared and yq bins
wget -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${cloudfalredRelease}/cloudflared-linux-${arch}"
wget -O /usr/bin/yq "https://github.com/mikefarah/yq/releases/download/${yqRelease}/yq_linux_${arch}"

# Make the downloaded bins executeable
chmod +x /usr/bin/cloudflared
chmod +x /usr/bin/yq