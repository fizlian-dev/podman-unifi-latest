#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
DATA_DIR="/usr/lib/unifi/data"
LOG_DIR="/usr/lib/unifi/logs"
CERT_DIR="/usr/lib/unifi/cert"
RUN_DIR="/var/run/unifi"
MONGO_LOG_FILE="${LOG_DIR}/mongod.log"
SERVER_LOG_FILE="${LOG_DIR}/server.log"
MONGO_LOCK_FILE="/var/lib/mongodb/mongod.lock" # Default mongo lock path from package

# Use PUID/PGID from environment, default to 999 if not set
UNIFI_UID=${PUID:-999}
UNIFI_GID=${PGID:-999}
UNIFI_USER="unifi" # Username the unifi package creates

# --- Functions ---
shutdown() {
  echo "Received stop signal. Shutting down..."

  # Stop UniFi Service
  if [ -x /etc/init.d/unifi ]; then
    echo "Stopping UniFi service..."
    # Use gosu to run as the correct user if needed, though stop might need root privilege
    # Trying stop with root first as it often requires it
    /etc/init.d/unifi stop || echo "WARN: UniFi stop command returned non-zero exit code."
  else
    echo "WARN: UniFi init script not found or not executable. Attempting pkill..."
    pkill -f 'jsvc.*unifi' || true
    sleep 2 # Give processes time to exit
  fi

  # Stop MongoDB
  if [ -f "$MONGO_LOCK_FILE" ] || pgrep -f mongod > /dev/null; then
    if pgrep -f mongod > /dev/null; then
      echo "Stopping MongoDB..."
      # Use mongod's shutdown command
      mongod --dbpath /var/lib/mongodb --shutdown || echo "WARN: MongoDB shutdown command failed."
      # Wait briefly for mongod to exit
      for _ in {1..10}; do [ ! -f "$MONGO_LOCK_FILE" ] && ! pgrep -f mongod > /dev/null && break || sleep 1; done
      # Force kill if still running
      pkill -SIGKILL -f mongod || true # Use SIGKILL as last resort
    fi
     # Clean up lock file just in case
     rm -f "$MONGO_LOCK_FILE"
  else
      echo "MongoDB lock file not found and process not running."
  fi

  echo "Shutdown complete."
  exit 0 # Exit cleanly
}

# --- Main Script ---

# Setup signal traps for graceful shutdown
trap shutdown SIGTERM SIGINT

# 1. Check/Update UniFi User/Group IDs
echo "Checking UniFi user ${UNIFI_USER} UID/GID (${UNIFI_UID}/${UNIFI_GID})..."
CURRENT_GID=$(id -g ${UNIFI_USER} 2>/dev/null || echo "notfound")
CURRENT_UID=$(id -u ${UNIFI_USER} 2>/dev/null || echo "notfound")

if [ "$CURRENT_UID" = "notfound" ] || [ "$CURRENT_GID" = "notfound" ]; then
    echo "ERROR: User ${UNIFI_USER} not found. Package installation might have failed."
    exit 1
fi

# Change GID first if necessary
if [ "$CURRENT_GID" != "$UNIFI_GID" ]; then
    echo "Updating ${UNIFI_USER} GID from ${CURRENT_GID} to ${UNIFI_GID}..."
    groupmod -o -g ${UNIFI_GID} ${UNIFI_USER} # -o allows non-unique GID temporarily if needed
fi
# Change UID
if [ "$CURRENT_UID" != "$UNIFI_UID" ]; then
    echo "Updating ${UNIFI_USER} UID from ${CURRENT_UID} to ${UNIFI_UID}..."
    usermod -o -u ${UNIFI_UID} ${UNIFI_USER} # -o allows non-unique UID temporarily
fi

# 2. Ensure directories exist and set permissions
echo "Ensuring directories and permissions..."
mkdir -p ${RUN_DIR} ${DATA_DIR} ${LOG_DIR} ${CERT_DIR} /var/lib/mongodb /var/log/mongodb
# Set ownership - run dir for unifi, mongo dirs for mongodb, others for unifi user
chown -R ${UNIFI_UID}:${UNIFI_GID} ${RUN_DIR} ${DATA_DIR} ${LOG_DIR} ${CERT_DIR}
# Ensure mongodb user/group (created by mongodb-org package) owns its directories
if id mongodb > /dev/null 2>&1; then
  chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb
else
  echo "WARN: mongodb user/group not found, skipping chown for mongo dirs."
fi


# 3. Start MongoDB
if ! pgrep -f mongod > /dev/null; then
    echo "Starting MongoDB..."
    rm -f "$MONGO_LOCK_FILE"
    # Use gosu to run as the mongodb user
    gosu mongodb:mongodb mongod --dbpath /var/lib/mongodb --logpath ${MONGO_LOG_FILE} --logappend
    # Wait for MongoDB to be ready
    echo "Waiting for MongoDB to start..."
    WAIT_COUNT=0
    MAX_WAIT=30
    # Check if mongo process exists and if lock file has been created
    until pgrep -f mongod > /dev/null && [ -f "$MONGO_LOCK_FILE" ] || [ $WAIT_COUNT -eq $MAX_WAIT ]; do
        sleep 1
        ((WAIT_COUNT++))
        echo -n "."
    done
    echo # Newline after dots
    if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
        echo "ERROR: MongoDB did not start within ${MAX_WAIT} seconds. Check ${MONGO_LOG_FILE}"
        # Attempt to capture last few lines of mongo log
        tail -n 20 ${MONGO_LOG_FILE} || true
        exit 1
    fi
    echo "MongoDB started."
else
    echo "MongoDB appears to be running."
fi

# 4. Start UniFi Service
echo "Starting UniFi service as user ${UNIFI_USER} (${UNIFI_UID}:${UNIFI_GID})..."
# Ensure log files exist for tailing
touch ${SERVER_LOG_FILE} ${MONGO_LOG_FILE}
chown ${UNIFI_UID}:${UNIFI_GID} ${SERVER_LOG_FILE} ${MONGO_LOG_FILE}

# Use gosu to run the init script start command as the UniFi user
gosu ${UNIFI_UID}:${UNIFI_GID} /etc/init.d/unifi start

# 5. Keep container running by tailing logs
echo "UniFi service started. Tailing logs ${SERVER_LOG_FILE} and ${MONGO_LOG_FILE}..."
# Tail both logs in the background, manage PIDs
tail -n 0 -F ${SERVER_LOG_FILE} &
TAIL_SERVER_PID=$!
tail -n 0 -F ${MONGO_LOG_FILE} &
TAIL_MONGO_PID=$!

# Wait indefinitely for any background job (tail) to exit or for a signal
# This keeps the container alive while allowing logs to be followed
# Use wait -n to wait for the next job to exit
wait -n ${TAIL_SERVER_PID} ${TAIL_MONGO_PID}

# If we reach here, one of the tail processes died unexpectedly.
# The trap should handle SIGTERM/SIGINT, but we can add cleanup just in case.
echo "WARN: Log tailing process ended unexpectedly. Initiating shutdown..."
shutdown
