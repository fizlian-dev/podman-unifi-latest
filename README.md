  # unifi
Podman Container for the latest version of the Unifi Network Server

  # How to build
  
podman build \
  -t podman-unifi-latest:latest \
  https://github.com/fizlian-dev/podman-unifi-latest.git#main

  # Example location, choose what suits you
  
HOST_DATA_PATH="$HOME/podman_volumes/unifi-latest"
mkdir -p ${HOST_DATA_PATH}/{data,logs,cert}

  # Use the UID/GID matching the PUID/PGID used during build (default 999)
  
HOST_DATA_PATH="$HOME/podman_volumes/unifi-latest"
sudo chown -R 999:999 ${HOST_DATA_PATH}

  # Run the continaer

  # STEP 1: Define the variable (Use the ACTUAL path you created and chown'd)
HOST_DATA_PATH="$HOME/podman_volumes/unifi-latest"

# STEP 2: Run the command (Variable will be expanded correctly by YOUR shell)
#          (End-of-line comments removed for safety)
podman run -d --name unifi-latest \
  --restart unless-stopped \
  --network bridge \
  -p 8443:8443/tcp \
  -p 8080:8080/tcp \
  -p 3478:3478/udp \
  -p 10001:10001/udp \
  -p 8880:8880/tcp \
  -p 8843:8843/tcp \
  -p 6789:6789/tcp \
  -v "${HOST_DATA_PATH}/data:/usr/lib/unifi/data:Z" \
  -v "${HOST_DATA_PATH}/logs:/usr/lib/unifi/logs:Z" \
  -v "${HOST_DATA_PATH}/cert:/usr/lib/unifi/cert:Z" \
  -e TZ="America/New_York" \
  -e PUID=999 \
  -e PGID=999 \
  podman-unifi-latest:latest
