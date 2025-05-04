  # unifi
Podman Container for the latest version of the Unifi Network Server

  # How to build
  
podman build \
  -t podman-unifi-latest:latest \
  https://github.com/fizlian-dev/podman-unifi-latest.git#main

  # Example location, choose what suits you
  
HOST_DATA_PATH="$HOME/podman_volumes/unifi-latest"
<mkdir -p ${HOST_DATA_PATH}/{data,logs,cert}>

  # Use the UID/GID matching the PUID/PGID used during build (default 999)
  
sudo chown -R 999:999 ${HOST_DATA_PATH}

  # Run the continaer

  podman run -d --name unifi-latest \
  --restart unless-stopped \
  --network bridge \
  -p 8443:8443/tcp `# UI HTTPS` \
  -p 8080:8080/tcp `# Device Inform` \
  -p 3478:3478/udp `# STUN` \
  -p 10001:10001/udp `# L2 Discovery` \
  -p 8880:8880/tcp `# Portal HTTP` \
  -p 8843:8843/tcp `# Portal HTTPS` \
  -p 6789:6789/tcp `# Mobile Speed Test` \
  -v ${HOST_DATA_PATH}/data:/usr/lib/unifi/data:Z \
  -v ${HOST_DATA_PATH}/logs:/usr/lib/unifi/logs:Z \
  -v ${HOST_DATA_PATH}/cert:/usr/lib/unifi/cert:Z \
  -e TZ="America/New_York" `# Ensure this matches your timezone` \
  -e PUID=999 `# Optional: Pass if you used non-default build arg and need entrypoint to know` \
  -e PGID=999 `# Optional: Pass if you used non-default build arg and need entrypoint to know` \
  # -e JVM_MAX_HEAP_SIZE="1024M" # Optional: Adjust Java max memory
  my-unifi:latest # Use the tag you gave your built image
