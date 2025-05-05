# Stage 1: Find Latest UniFi Version and URL from ui.com/download/releases/network-server
FROM debian:bookworm-slim AS finder

# Install tools needed for scraping
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates grep sed && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Attempt to find the latest .deb download URL from the specified page
# FRAGILE: This relies entirely on the current HTML structure and link format of Ubiquiti's page!
RUN \
    TARGET_URL="https://ui.com/download/releases/network-server" && \
    echo "Attempting to find latest UniFi .deb download URL from ${TARGET_URL}..." && \
    # This attempts to find the FIRST href containing '.deb' on the page. Highly speculative!
    # It might grab the wrong architecture or an unrelated .deb file. Needs refinement based on actual page source.
    LATEST_DEB_URL=$(curl -sSL "${TARGET_URL}" | \
                     grep -oP 'href="([^"]*unifi_sysvinit_all[^"]*\.deb)"' | \
                     head -n 1 | \
                     sed -e 's/href="//' -e 's/"$//') && \
    # Check if the result is a full URL or relative path (unlikely for dl.ui.com but just in case)
    if [[ ! "$LATEST_DEB_URL" =~ ^https?:// ]]; then \
        LATEST_DEB_URL="https://dl.ui.com${LATEST_DEB_URL}"; \
    fi && \
    # Basic check if we got something plausible
    if [ -z "$LATEST_DEB_URL" ] || [[ "$LATEST_DEB_URL" != *.deb ]]; then \
        echo "ERROR: Could not automatically find a valid .deb URL on ${TARGET_URL}. Scraping failed."; \
        exit 1; \
    fi && \
    echo "Found potential URL: ${LATEST_DEB_URL}" && \
    # Save the found URL to a file for the next stage
    echo "${LATEST_DEB_URL}" > /tmp/unifi_url.txt

# Stage 2: Build the actual image using the found URL
FROM debian:bookworm-slim

# Copy the found URL from the finder stage
COPY --from=finder /tmp/unifi_url.txt /tmp/unifi_url.txt

ARG TZ="America/New_York"
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}
ARG PUID=1000
ARG PGID=100
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
    wget --progress=dot:giga -O /tmp/unifi.deb "${UNIFI_DEB_URL}" && \
    # Install the downloaded .deb package
    echo "Installing UniFi Controller..." && \
    dpkg -i /tmp/unifi.deb && \
    # Attempt to fix any missing dependencies
    echo "Fixing dependencies..." && \
    apt-get install -f -y --no-install-recommends && \
    # Set timezone
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # Clean up
    rm /tmp/unifi.deb /tmp/unifi_url.txt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- Rest of the Containerfile is the same ---
VOLUME ["/usr/lib/unifi/data", "/usr/lib/unifi/logs", "/usr/lib/unifi/cert", "/var/run/unifi"]
EXPOSE 8443/tcp 8080/tcp 3478/udp 10001/udp 8880/tcp 8843/tcp 6789/tcp
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["unifi"]
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
  CMD curl --fail --insecure https://localhost:8443/status || exit 1
# Metadata labels (optional)
LABEL org.opencontainers.image.title="UniFi Network Application Server (Latest Scraped)" \
      org.opencontainers.image.description="Self-built container attempting to scrape latest UniFi deb with MongoDB 8.0" \
      org.opencontainers.image.source="https://github.com/fizlian-dev/podman-unifi-latest"
