#!/bin/bash

# UHF Server Entrypoint Script
# Handles environment configuration and server startup

set -e

# Default values (can be overridden by environment variables)
PORT="${UHF_PORT:-8000}"
RECORDINGS_DIR="${UHF_RECORDINGS_DIR:-/recordings}"
DATA_DIR="${UHF_DATA_DIR:-/var/lib/uhf-server}"
ENABLE_COMMERCIAL_DETECTION="${UHF_ENABLE_COMMERCIAL_DETECTION:-true}"
COMSKIP_ARGS="${COMSKIP_ARGS:---ini}"
LOG_LEVEL="${LOG_LEVEL:-info}"

# Ensure directories exist
mkdir -p "${RECORDINGS_DIR}" "${DATA_DIR}"

# Build UHF Server command
UHF_CMD="/app/uhf-server"
# Note: --db-path expects a file path, not a directory
DB_FILE="${DATA_DIR}/uhf.db"
UHF_ARGS=(
    "--port" "${PORT}"
    "--recordings-dir" "${RECORDINGS_DIR}"
    "--db-path" "${DB_FILE}"
)

# Add commercial detection flag if enabled
if [ "${ENABLE_COMMERCIAL_DETECTION}" = "true" ] || [ "${ENABLE_COMMERCIAL_DETECTION}" = "1" ]; then
    UHF_ARGS+=("--enable-commercial-detection")
fi

# Add log level if specified (supported by UHF Server)
if [ -n "${LOG_LEVEL}" ]; then
    UHF_ARGS+=("--log-level" "${LOG_LEVEL}")
fi

# Log configuration
echo "=========================================="
echo "UHF Server Configuration"
echo "=========================================="
echo "Port: ${PORT}"
echo "Recordings Directory: ${RECORDINGS_DIR}"
echo "Data Directory: ${DATA_DIR}"
echo "Commercial Detection: ${ENABLE_COMMERCIAL_DETECTION}"
echo "Comskip Args: ${COMSKIP_ARGS}"
echo "Log Level: ${LOG_LEVEL}"
echo "=========================================="
echo ""

# Start UHF Server with systemd-inhibit to prevent idle sleep
# systemd-inhibit prevents the system from going idle while recording
# If systemd-inhibit is unavailable, run UHF Server directly
echo "Starting UHF Server..."
if command -v systemd-inhibit &> /dev/null; then
    echo "Using systemd-inhibit to prevent idle sleep..."
    exec systemd-inhibit --what=idle --why="uhf-server recording" \
        "${UHF_CMD}" "${UHF_ARGS[@]}"
else
    echo "Warning: systemd-inhibit not available, starting without sleep prevention"
    exec "${UHF_CMD}" "${UHF_ARGS[@]}"
fi
