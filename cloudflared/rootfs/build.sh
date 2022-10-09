#!/bin/sh
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Container build of Cloudflared
# ==============================================================================

# Machine architecture as first parameter
arch=$1

# Dependency releases to build from
cloudflaredRelease=$(jq -r .version /cloudflared_version.json )

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

# Download the cloudflared bin
wget -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${cloudflaredRelease}/cloudflared-linux-${arch}"

# Make the downloaded bin executeable
chmod +x /usr/bin/cloudflared

# Remove legacy cont-init.d services
rm -rf /etc/cont-init.d

# Add needed packages
apk add --no-cache \
    yq=4.25.1-r5
