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
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg > /etc/apt/trusted.gpg.d/unifi-repo.gpg && \
    echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org unifi && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
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
