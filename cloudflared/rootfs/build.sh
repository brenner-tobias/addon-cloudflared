#!/bin/sh
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Container build of Cloudflared
# ==============================================================================

# Machine architecture as first parameter
arch=$1

# Cloudflared release as second parameter
cloudflaredRelease=$2

# Adapt the architecture to the cloudflared specific names if needed
# see HA Archs: https://developers.home-assistant.io/docs/add-ons/configuration/#:~:text=the%20add%2Don.-,arch,-list
# see Cloudflared Archs https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation
case $arch in
    "aarch64")
        arch="arm64"
    ;;

    "armv7")
        arch="arm"
    ;;
esac

# Workaround for live log streaming issue
# see https://github.com/brenner-tobias/addon-cloudflared/discussions/744

# renovate: datasource=repology depName=debian_12/gnupg versioning=loose
nginx_version="1.28.0-r3"
apk add --no-cache nginx="${nginx_version}"

# Download the cloudflared bin
wget -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${cloudflaredRelease}/cloudflared-linux-${arch}"

# Make the downloaded bin executeable
chmod +x /usr/bin/cloudflared

# Remove legacy cont-init.d services
rm -rf /etc/cont-init.d

# Remove s-6 legacy/deprecated (and not needed) services
rm /package/admin/s6-overlay/etc/s6-rc/sources/base/contents.d/legacy-cont-init
rm /package/admin/s6-overlay/etc/s6-rc/sources/base/contents.d/fix-attrs
rm /package/admin/s6-overlay/etc/s6-rc/sources/top/contents.d/legacy-services
