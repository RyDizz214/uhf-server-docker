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
# Accept upstream's SINGLE_FILE_RECORDINGS name too (requires uhf-server 2.2.0+)
SINGLE_FILE_RECORDINGS="${UHF_SINGLE_FILE_RECORDINGS:-${SINGLE_FILE_RECORDINGS:-false}}"

# Ensure system localtime matches TZ.
# The image ships /etc/localtime -> Etc/UTC. uhf-server evaluates recurring
# schedule weekdays from /etc/localtime (not $TZ), so without this the whole
# weekday window is shifted to UTC (e.g. an 8pm ET show lands on the next UTC
# day, turning a Mon-Fri rule into Sun-Thu). Repair the symlink from $TZ.
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
    echo "Timezone set to ${TZ} (/etc/localtime -> /usr/share/zoneinfo/${TZ})"
fi

# Fix .ts MIME type. Ubuntu's /etc/mime.types maps .ts to
# text/vnd.trolltech.linguist (Qt Linguist files), not video/mp2t. Legacy
# (pre-HLS) recordings served via /dvr/recordings/{id}/stream rely on
# Python's mimetypes.guess_type(), which reads this file - so playback
# clients receive the wrong Content-Type and refuse to play the stream.
if [ -f /etc/mime.types ]; then
    sed -i 's#^text/vnd.trolltech.linguist[[:space:]]\+ts$#video/mp2t\t\t\t\tts#' /etc/mime.types
fi

# Ensure directories exist
mkdir -p "${RECORDINGS_DIR}" "${DATA_DIR}"

# Find UHF Server binary (location varies by image version)
if [ -x "/app/uhf-server" ]; then
    UHF_CMD="/app/uhf-server"
elif command -v uhf-server &> /dev/null; then
    UHF_CMD="uhf-server"
else
    echo "ERROR: uhf-server binary not found!"
    exit 1
fi
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

# Merge each finished recording's HLS segments into one index.ts.
# The merge briefly needs twice the recording's size on disk.
if [ "${SINGLE_FILE_RECORDINGS}" = "true" ] || [ "${SINGLE_FILE_RECORDINGS}" = "1" ]; then
    UHF_ARGS+=("--single-file-recordings")
fi

# Add server password if specified. Without one, 2.1.0+ hands a session
# token to anyone who calls /auth/password-login.
# Passed via the environment (uhf-server reads SERVER_PASSWORD), not --password:
# command lines are world-readable in ps / /proc/<pid>/cmdline, even on the host.
if [ -n "${UHF_PASSWORD}" ]; then
    export SERVER_PASSWORD="${UHF_PASSWORD}"
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
echo "Single-File Recordings: ${SINGLE_FILE_RECORDINGS}"
echo "Password: $([ -n "${UHF_PASSWORD}" ] && echo set || echo NOT SET)"
echo "=========================================="
echo ""

# Start UHF Server with systemd-inhibit to prevent idle sleep
# systemd-inhibit prevents the system from going idle while recording.
# It needs the host's D-Bus socket mounted (see README); without it,
# systemd-inhibit exits immediately, so run UHF Server directly instead.
echo "Starting UHF Server..."
if command -v systemd-inhibit &> /dev/null && [ -S /run/dbus/system_bus_socket ]; then
    echo "Using systemd-inhibit to prevent idle sleep..."
    exec systemd-inhibit --what=idle --why="uhf-server recording" \
        "${UHF_CMD}" "${UHF_ARGS[@]}"
else
    echo "systemd-inhibit or host D-Bus not available, starting without sleep prevention"
    exec "${UHF_CMD}" "${UHF_ARGS[@]}"
fi
