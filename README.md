# UHF Server Docker

A Dockerized setup for UHF Server with built-in Comskip commercial detection. This repository contains:

* A custom `Dockerfile` that compiles and installs Comskip from source on Ubuntu 25.04 alongside FFmpeg 7.1.1.
* A `docker-compose.yml` for running the UHF Server container with environment-driven configuration.
* A sample `.env` file template for all required environment variables.
* Instructions to build, configure, and run the UHF Server image with Comskip integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Repository Structure](#repository-structure)
5. [Environment Variables](#environment-variables)
6. [Building the Docker Image](#building-the-docker-image)
7. [Running with Docker Compose](#running-with-docker-compose)
8. [Using Comskip for Commercial Detection](#using-comskip-for-commercial-detection)
9. [Healthcheck](#healthcheck)
10. [Logging and Volumes](#logging-and-volumes)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This project provides a fully containerized UHF Server environment on Ubuntu 25.04. It bundles:

* **UHF Server** (installed via the official setup script).
* **FFmpeg 7.1.1** (from Ubuntu 25.04 repos) for encoding/transcoding.
* **Comskip** (compiled from source) for commercial detection on recorded `.ts` files.

With these components, UHF Server will automatically run Comskip against any completed recording (in `/recordings`), generating `.ini` and `.log` files alongside each `.ts` to drive commercial-skip logic.

---

## Features

* **Comskip integration**: Automatically detect commercials in `.ts` recordings.
* **Environment-driven configuration**: All ports, directories, and settings come from a `.env` file.
* **Healthcheck**: A built-in Docker Healthcheck pings the UHF `/server/stats` endpoint.
* **Persistent storage**: Recordings and UHF data (database, logs, etc.) persist via Docker volumes.
* **FFmpeg 7.1.1**: Uses the Ubuntu 25.04 package of FFmpeg 7.1.1 for optimal compatibility.

---

## Prerequisites

Before you begin, ensure you have:

* **Docker Engine** (≥ 24.x) installed on your host machine.
* **Docker Compose** (≥ v2.0) installed.
* A valid **UHF Server license** or access to the official UHF setup script URL.
* Basic familiarity with environment variables and Docker networking.

---

## Repository Structure

```text
/opt/uhf-server-docker
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── README.md
└── (other UHF repo files from upstream)
```

* **Dockerfile** – Builds an Ubuntu 25.04-based image with UHF Server, FFmpeg 7.1.1, and Comskip.
* **docker-compose.yml** – Defines the `uhf-server` service, volumes, ports, and environment.
* **.env.example** – Template for environment variables; copy to `.env` and adjust.
* **README.md** – This documentation.
* **(other UHF repo files)** – The original UHF Server source code and configuration from the cloned upstream repository.

---

## Environment Variables

Copy `​.env.example` to `​.env` and fill in values:

```ini
# .env

# UHF Server port (HTTP)
PORT=8080

# Host directory for recordings (bind-mount to container:/recordings)
HOST_RECORDINGS_DIR=/path/to/recordings

# Host directory for UHF database or other server data
HOST_UHF_DATA_DIR=/path/to/uhf-data

# Timezone (optional; defaults to UTC inside container)
TZ=America/New_York

# Comskip additional arguments (optional)
COMSKIP_ARGS=--ini

# Optional password protection
# PASSWORD=mysecretpassword
```

* **PORT** – Port on which UHF Server’s web interface and API listen.
* **HOST\_RECORDINGS\_DIR** – Absolute path on the host where your `.ts` recordings will live; mounted as `/recordings` inside the container.
* **HOST\_UHF\_DATA\_DIR** – Absolute path for UHF Server’s data (database, logs, etc.); mounted as `/var/lib/uhf-server`.
* **TZ** – Container timezone; set if you want logs/timestamps in your local zone.
* **COMSKIP\_ARGS** – Any extra CLI flags you want Comskip to use (default is `--ini`).

---

## Building the Docker Image

1. **Navigate to the project directory**:

   ```bash
   cd /opt/uhf-server-docker
   ```

2. **Ensure your `.env` file exists** (copy from `.env.example` if needed):

   ```bash
   cp .env.example .env
   # Edit .env to set HOST_RECORDINGS_DIR, HOST_UHF_DATA_DIR, and other values
   ```

3. **Build the Docker image** with the version tag `1.4.0`:

   ```bash
   docker build \
     -t ghcr.io/RyDizz214/uhf-server-docker:1.4.0 \
     .
   ```

   The build will:

   * Update Ubuntu 25.04 packages (with `--allow-releaseinfo-change --fix-missing`).
   * Install FFmpeg 7.1.1, Git, build tools, and runtime dependencies (like `libargtable2-0`).
   * Clone, configure, and compile **Comskip** from its GitHub repo.
   * Purge build-only packages, leaving a minimal runtime footprint.
   * Run the official UHF Server setup script to install UHF into `/app`.

4. **Verify Comskip is installed**:

   ```bash
   docker run --rm ghcr.io/RyDizz214/uhf-server-docker:1.4.0 which comskip
   # Expected output: /usr/local/bin/comskip
   ```

---

## Running with Docker Compose

Once the image is built, use `docker-compose` to start UHF Server:

1. **Start the service**:

   ```bash
   docker-compose up -d
   ```

   Docker Compose will:

   * Create two named volumes or host-bind mounts (`/recordings` and `/var/lib/uhf-server`).
   * Map `${PORT}` from your `.env` to container port 8080 (UHF’s default).
   * Set environment variables inside the container (including `TZ`).

2. **Check container status**:

   ```bash
   docker-compose ps
   ```

   You should see `uhf-server` in the “Up (healthy)” state once the healthcheck passes.

3. **View logs** (to confirm UHF and Comskip startup):

   ```bash
   docker-compose logs -f
   ```

4. **Access UHF Web UI**:
   Open `http://<HOST_IP>:${PORT}` in your browser to confirm UHF Server is running.

---

## Using Comskip for Commercial Detection

UHF Server is configured so that, after each recording finishes, it automatically calls Comskip on the new `.ts` file. By default:

* UHF stores recordings under `/recordings/<show>.ts`.
* The internal post-processing script uses:

  ```bash
  /usr/local/bin/comskip ${COMSKIP_ARGS} /recordings/<show>.ts
  ```
* Comskip generates `<show>.ini` and `<show>.log` files alongside the `.ts`, which UHF can use to skip commercials.

### Customizing Comskip behavior

* Edit `/app/config/comskip.ini` (inside the container) if you need to adjust thresholds, patterns, or output formats.
* Override default CLI flags by setting `COMSKIP_ARGS` in your `.env`, for example:

  ```ini
  COMSKIP_ARGS="--ini --detectfiller"
  ```
* To run Comskip manually on a host-mounted recording:

  ```bash
  docker run --rm \
    -v /path/to/recordings:/recordings \
    ghcr.io/RyDizz214/uhf-server-docker:1.4.0 \
    comskip --ini /recordings/Example_Show_2025.06.03.ts
  ```

---

## Healthcheck

A Docker Healthcheck polls the UHF Server stats endpoint every 60 seconds:

```dockerfile
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT}/server/stats || exit 1
```

* If `/server/stats` returns HTTP 200, the container is marked healthy.
* Otherwise, Docker will restart the container after three consecutive failures.

You can view health status with:

```bash
docker ps
# Look under "STATUS" column for "(healthy)" or "(unhealthy)"
```

---

## Logging and Volumes

* **Recordings Volume**:

  * Host path: `${HOST_RECORDINGS_DIR}` → Container: `/recordings`
  * Stores all live-TV `.ts` files.
* **UHF Data Volume**:

  * Host path: `${HOST_UHF_DATA_DIR}` → Container: `/var/lib/uhf-server`
  * Stores UHF’s database, metadata, and Comskip output files.
* **Container Logs**:
  UHF Server logs to `stdout` by default; use `docker-compose logs -f` to view.
  If you want to persist logs to disk, you can redirect logs inside your `docker-compose.yml` or mount a log directory.
