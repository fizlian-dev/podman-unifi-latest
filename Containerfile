# Stage 1: Find Latest UniFi Version and URL using Link Title Attribute
FROM debian:bookworm-slim AS finder

# Install tools needed for scraping
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates grep sed && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Attempt to find the latest .deb download URL by parsing the link title
# FRAGILE: This relies on the specific title attribute format "Download v X.Y.Z (Linux)"
RUN \
    TARGET_URL="https://ui.com/download/releases/network-server" && \
    echo "Attempting to find latest UniFi .deb version from ${TARGET_URL}..." && \
    # Extract version number X.Y.Z from the first link matching the title pattern
    # Assumes the first match corresponds to the latest version listed.
    VERSION=$(curl -sSL "${TARGET_URL}" | \
              grep -oP 'title="Download v (\d+\.\d+\.\d+) \(Linux\)"' | \
              head -n 1 | \
              sed -n 's/.* v \([0-9.]*\) .*/\1/p') && \
    # Check if version was found
    if [ -z "$VERSION" ]; then \
        echo "ERROR: Could not extract latest version number using title attribute from ${TARGET_URL}. Scraping failed."; \
        exit 1; \
    fi && \
    # Construct the URL based on the identified pattern
    LATEST_DEB_URL="https://dl.ui.com/unifi/${VERSION}/unifi_sysvinit_all.deb" && \
    echo "Found Version: ${VERSION}" && \
    echo "Constructed URL: ${LATEST_DEB_URL}" && \
    # Save the found URL to a file for the next stage
    echo "${LATEST_DEB_URL}" > /tmp/unifi_url.txt

# Stage 2: Build the actual image using the found URL
FROM debian:bookworm-slim

COPY --from=finder /tmp/unifi_url.txt /tmp/unifi_url.txt

ARG TZ="America/New_York"
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}
ARG PUID=1000
ARG PGID=100
ENV PUID=${PUID}
ENV PGID=${PGID}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg procps tini sudo gosu jq wget && \
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org && \
    UNIFI_DEB_URL=$(cat /tmp/unifi_url.txt) && \
    echo "Downloading UniFi Controller from ${UNIFI_DEB_URL}..." && \
    wget --progress=dot:giga -O /tmp/unifi.deb "${UNIFI_DEB_URL}" && \
    echo "Installing UniFi Controller..." && \
    dpkg -i /tmp/unifi.deb && \
    echo "Fixing dependencies..." && \
    apt-get install -f -y --no-install-recommends && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm /tmp/unifi.deb /tmp/unifi_url.txt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/usr/lib/unifi/data", "/usr/lib/unifi/logs", "/usr/lib/unifi/cert", "/var/run/unifi"]
EXPOSE 8443/tcp 8080/tcp 3478/udp 10001/udp 8880/tcp 8843/tcp 6789/tcp
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["unifi"]
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
  CMD curl --fail --insecure https://localhost:8443/status || exit 1
