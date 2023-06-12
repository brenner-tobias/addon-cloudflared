ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:14.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set S6 verbosity level
ENV S6_VERBOSITY=1

# Setup base
ARG BUILD_ARCH=amd64
ARG CLOUDFLARED_VERSION="2023.5.1"

# Copy root filesystem
COPY rootfs /

# Run the script that installes cloudflared
RUN chmod a+x /build.sh && /build.sh "${BUILD_ARCH}" "${CLOUDFLARED_VERSION}"

# Build arguments
ARG BUILD_ARCH
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
    io.hass.version=${BUILD_VERSION} \
    maintainer="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.authors="Tobias Brenner <https://github.com/brenner-tobias/>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
