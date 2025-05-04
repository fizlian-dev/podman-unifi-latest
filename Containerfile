# Containerfile for UniFi Network Application (Latest Stable + MongoDB 8.0)

# Use Debian Bookworm Slim as the base OS
FROM debian:bookworm-slim

# Set Non-Interactive Frontend and Timezone (Adjust TZ default as needed)
ARG TZ="America/New_York"
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}

# Define UniFi User/Group IDs (Allow overriding, default 999 matches common practice)
ARG PUID=999
ARG PGID=999
ENV PUID=${PUID}
ENV PGID=${PGID}

# Install dependencies, add repositories, install UniFi & MongoDB 8.0
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        procps \
        tini \
        sudo \
        gosu \
        jq && \
    # Install Java (UniFi >= 9.x supports Java 17/21)
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    # Add MongoDB GPG Key & Repository (Using MongoDB 8.0, compatible with UniFi >= 9.x)
    # Ref: https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-debian/
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    # Add Ubiquiti GPG Key & Repository for latest stable UniFi
    # Ref: https://help.ui.com/hc/en-us/articles/220066768
    curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg > /etc/apt/trusted.gpg.d/unifi-repo.gpg && \
    echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list && \
    # Update sources and install MongoDB 8.0 and latest UniFi from repo
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org unifi && \
    # Set timezone system-wide
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # Clean up APT caches to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Define standard UniFi directories as volumes
VOLUME ["/usr/lib/unifi/data", "/usr/lib/unifi/logs", "/usr/lib/unifi/cert", "/var/run/unifi"]

# Expose standard UniFi ports
# Controller UI: 8443 (HTTPS)
# Device Inform: 8080 (HTTP)
# STUN: 3478 (UDP)
# L2 Discovery: 10001 (UDP)
# Portal Redirect: 8880 (HTTP), 8843 (HTTPS)
# Mobile Speed Test: 6789 (TCP)
EXPOSE 8443/tcp 8080/tcp 3478/udp 10001/udp 8880/tcp 8843/tcp 6789/tcp

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use tini as the main entrypoint for proper signal handling & zombie reaping
# It will execute our entrypoint.sh script
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command passed to entrypoint (can be overridden)
CMD ["unifi"]

# Optional: Add a healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
  CMD curl --fail --insecure https://localhost:8443/status || exit 1

# Metadata labels (optional)
LABEL org.opencontainers.image.title="UniFi Network Application Server (Latest)" \
      org.opencontainers.image.description="Self-built container for the latest UniFi Network Application with MongoDB 8.0" \
      org.opencontainers.image.source="https://github.com/<your-github-username>/podman-unifi-latest" # Replace with your actual repo URL
