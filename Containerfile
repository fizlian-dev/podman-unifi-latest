# Containerfile for UniFi Network Application (Installs Latest Stable from APT)

FROM debian:bookworm-slim

# Set Non-Interactive Frontend and Timezone
ARG TZ="America/New_York"
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}

# Define UniFi User/Group IDs
ARG PUID=1000
ARG PGID=100
ENV PUID=${PUID}
ENV PGID=${PGID}

# Install dependencies, add repositories, install latest UniFi & MongoDB 8.0 from repos
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg procps tini sudo gosu jq && \
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    # Add MongoDB GPG Key & Repository (Using MongoDB 8.0)
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    # Add Ubiquiti GPG Key & Repository for latest stable UniFi
    curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg > /etc/apt/trusted.gpg.d/unifi-repo.gpg && \
    echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list && \
    # Update sources and install MongoDB 8.0 and latest UniFi from repo
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org unifi && \
    # Set timezone
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # Clean up APT caches
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Define standard UniFi directories as volumes
VOLUME ["/usr/lib/unifi/data", "/usr/lib/unifi/logs", "/usr/lib/unifi/cert", "/var/run/unifi"]

# Expose standard UniFi ports
EXPOSE 8443/tcp 8080/tcp 3478/udp 10001/udp 8880/tcp 8843/tcp 6789/tcp

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use tini as the main entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command
CMD ["unifi"]

# Optional: Add a healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
  CMD curl --fail --insecure https://localhost:8443/status || exit 1
