# Stage 1: Find Latest UniFi URL using Python
FROM python:3.11-slim-bookworm AS finder

# Install dependencies for Python script
RUN python3 ./find_latest.py

WORKDIR /app

# Copy the Python script into the finder stage
COPY find_latest.py .
RUN chmod +x find_latest.py

# Execute the script and save the output URL
# FRAGILE: This build stage will fail if the website structure changes
# or if the script cannot reliably find the latest version URL.
RUN \
    echo "Running Python script to find latest UniFi URL..." && \
    LATEST_DEB_URL=$(python3 ./find_latest.py) && \
    if [ -z "$LATEST_DEB_URL" ]; then \
        echo "ERROR: Python script failed to output a URL."; \
        exit 1; \
    fi && \
    echo "Script found URL: ${LATEST_DEB_URL}" && \
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
