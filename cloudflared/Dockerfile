FROM ghcr.io/hassio-addons/base:18.2.0

# Set S6 verbosity level
ENV S6_VERBOSITY="1"

# Setup base
ARG BUILD_ARCH="amd64"

# renovate: datasource=repology depName=yq packageName=alpine_3_22/yq-go versioning=loose
ARG YQ_VERSION="4.47.2-r1"
# renovate: datasource=github-releases depName=cloudflared packageName=cloudflare/cloudflared versioning=loose
ARG CLOUDFLARED_VERSION="2025.9.1"

# Copy root filesystem
COPY rootfs /

# Run the script that installs caddy and cloudflared
RUN ["/build.sh"]

CMD ["/run.sh"]

# Build arguments
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.authors="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"
