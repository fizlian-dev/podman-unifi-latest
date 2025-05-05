# Containerfile for UniFi Network Application (Latest Stable + MongoDB 8.0)

# Stage 1: Find Latest UniFi Version and URL
FROM debian:bookworm-slim AS finder

# Install tools needed for scraping
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates grep sed && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Attempt to find the latest version and construct the download URL
# FRAGILE: This relies on Ubiquiti's website structure/URL patterns!
# Target page (example - might change)
ARG RELEASE_PAGE_URL="https://community.ui.com/releases"
# Base download URL pattern (example - might change)
ARG DOWNLOAD_BASE_URL="https://dl.ui.com/unifi"

# Scrape the page, find the latest Linux version link, extract version/path parts
# This specific command sequence is highly likely to break in the future.
RUN echo "Attempting to find latest UniFi download URL..." && \
    LATEST_INFO=$(curl -sSL ${RELEASE_PAGE_URL} | grep -oP 'href="(/releases/UniFi-Network-Application-\d+\.\d+\.\d+/.*?)"' | head -n 1 | sed -n 's/.*UniFi-Network-Application-\(\d\+\.\d\+\.\d\+\)\/\(.*\)\".*/\1 \2/p') && \
    if [ -z "$LATEST_INFO" ]; then echo "ERROR: Could not find latest version info on release page."; exit 1; fi && \
    UNIFI_VERSION=$(echo $LATEST_INFO | cut -d' ' -f1) && \
    UNIFI_RELEASE_ID=$(echo $LATEST_INFO | cut -d' ' -f2) && \
    if [ -z "$UNIFI_VERSION" ] || [ -z "$UNIFI_RELEASE_ID" ]; then echo "ERROR: Could not parse version/ID."; exit 1; fi && \
    # Construct the likely .deb URL (might need adjustment)
    DEB_URL="${DOWNLOAD_BASE_URL}/${UNIFI_VERSION}-${UNIFI_RELEASE_ID}/unifi_sysvinit_all.deb" && \
    echo "Found Version: ${UNIFI_VERSION}" && \
    echo "Constructed URL: ${DEB_URL}" && \
    # Check if URL seems valid (optional basic check)
    # curl --head --fail ${DEB_URL} || (echo "ERROR: Constructed URL seems invalid." && exit 1) && \
    # Save the found URL to a file for the next stage
    echo "${DEB_URL}" > /tmp/unifi_url.txt && \
    echo "${UNIFI_VERSION}" > /tmp/unifi_version.txt

# Stage 2: Build the actual image using the found URL
FROM debian:bookworm-slim

# Copy the found URL and Version from the finder stage
COPY --from=finder /tmp/unifi_url.txt /tmp/unifi_url.txt
COPY --from=finder /tmp/unifi_version.txt /tmp/unifi_version.txt

# Set Non-Interactive Frontend and Timezone
ARG TZ="America/New_York"
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}

# Define UniFi User/Group IDs
ARG PUID=999
ARG PGID=999
ENV PUID=${PUID}
ENV PGID=${PGID}

# Install dependencies, add MongoDB repo, download specific UniFi .deb, install
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg procps tini sudo gosu jq wget && \
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    # Add MongoDB Repo and Install MongoDB ONLY
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org && \
    # Read the URL found in stage 1 and download the .deb
    UNIFI_DEB_URL=$(cat /tmp/unifi_url.txt) && \
    echo "Downloading UniFi Controller from ${UNIFI_DEB_URL}..." && \
    wget -O /tmp/unifi.deb "${UNIFI_DEB_URL}" && \
    # Install the downloaded .deb package
    echo "Installing UniFi Controller..." && \
    dpkg -i /tmp/unifi.deb && \
    # Attempt to fix any missing dependencies
    echo "Fixing dependencies..." && \
    apt-get install -f -y --no-install-recommends && \
    # Set timezone
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # Clean up
    rm /tmp/unifi.deb /tmp/unifi_url.txt /tmp/unifi_version.txt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Define standard UniFi directories as volumes
VOLUME ["/usr/lib/unifi/data", "/usr/lib/unifi/logs", "/usr/lib/unifi/cert", "/var/run/unifi"]

# Expose standard UniFi ports
EXPOSE 8443/tcp 8080/tcp 3478/udp 10001/udp 8880/tcp 8843/tcp 6789/tcp

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use tini as the main entrypoint for proper signal handling & zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command passed to entrypoint (can be overridden)
CMD ["unifi"]

# Optional: Add a healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
  CMD curl --fail --insecure https://localhost:8443/status || exit 1

# Metadata labels (optional)
#LABEL org.opencontainers.image.title="UniFi Network Application Server (Latest)" \
#     org.opencontainers.image.description="Self-built container for the latest UniFi Network Application with MongoDB 8.0" \
#      org.opencontainers.image.source="https://github.com/fizlian-dev/podman-unifi-latest" # Updated Example URL
