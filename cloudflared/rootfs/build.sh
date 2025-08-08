#!/bin/sh
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Container build of Cloudflared
# ==============================================================================

set -eux

# Workaround for live log streaming issue
# see https://github.com/brenner-tobias/addon-cloudflared/discussions/744
apk add --no-cache nginx="${NGINX_VERSION}"

# Adapt the architecture to the cloudflared specific names if needed
# see HA archs: https://developers.home-assistant.io/docs/add-ons/configuration/#:~:text=the%20add%2Don.-,arch,-list
# see Cloudflared archs: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation
case "${BUILD_ARCH}" in
"aarch64")
    cloudflared_arch="arm64"
    ;;
"armv7")
    cloudflared_arch="arm"
    ;;
*)
    cloudflared_arch="${BUILD_ARCH}"
    ;;
esac

# Download the cloudflared bin
wget -q -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${cloudflared_arch}"

# Make the downloaded bin executeable
chmod +x /usr/bin/cloudflared

# Remove legacy cont-init.d services
rm -rf /etc/cont-init.d

# Remove s-6 legacy/deprecated (and not needed) services
rm -f /package/admin/s6-overlay/etc/s6-rc/sources/base/contents.d/legacy-cont-init
rm -f /package/admin/s6-overlay/etc/s6-rc/sources/base/contents.d/fix-attrs
rm -f /package/admin/s6-overlay/etc/s6-rc/sources/top/contents.d/legacy-services
