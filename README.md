# UHF Server Docker

A fully containerized UHF Server environment with FFmpeg 8.0, Comskip commercial detection, and systemd-inhibit for preventing idle sleep during recordings.

This project uses a **two-phase deployment model**: images are built once and pushed to a registry, then deployed via docker-compose with personal configuration. Similar to snappier-server.

## Features

* **UHF Server v1.5.1** - Latest version with HLS compatibility improvements
* **FFmpeg 8.0** - Compiled from source with full codec support (x264, x265, VP9, libopus, etc.)
* **Comskip integration** - Automatic commercial detection on recorded `.ts` files
* **systemd-inhibit** - Prevents system from entering idle/sleep mode during recordings
* **Environment-driven configuration** - Easy version updates and settings via `.env` file
* **Multi-stage Docker build** - Optimized for image size and fast builds
* **Healthcheck** - Built-in Docker Healthcheck monitoring
* **Persistent storage** - Recordings and UHF data persist via Docker volumes
* **Registry-based deployment** - Pre-built images for consistency across deployments

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Two-Phase Workflow](#two-phase-workflow)
4. [Prerequisites](#prerequisites)
5. [Environment Variables](#environment-variables)
6. [Running with Docker Compose](#running-with-docker-compose)
7. [Building & Pushing Images](#building--pushing-images)
8. [Architecture](#architecture)
9. [Troubleshooting](#troubleshooting)
10. [Full Documentation](#full-documentation)

---

## Overview

This project provides a fully containerized UHF Server environment based on Ubuntu 25.04. It includes:

* **UHF Server v1.5.1** - Downloaded from official GitHub releases
* **FFmpeg 8.0** - Built from source with comprehensive codec support
* **Comskip** - Compiled from source for commercial detection
* **systemd-inhibit** - Integrated to prevent idle sleep during recording

The Docker setup uses a **multi-stage build** approach:
1. **Stage 1** - Builds FFmpeg 8.0 from source with codec libraries
2. **Stage 2** - Builds Comskip from source
3. **Stage 3** - Creates the runtime container with compiled tools and UHF Server binary

---

## Two-Phase Workflow

This project uses a separation of concerns model:

**Phase 1: Build (One-time, per version)**
- Happens in the build environment
- Creates a Docker image with all dependencies baked in
- Image is pushed to a registry (ghcr.io)
- Uses: `./build.sh --push`

**Phase 2: Deploy (Per instance)**
- Happens on any machine with Docker
- Pulls the pre-built image from registry
- Applies personal configuration via `.env`
- Uses: `docker-compose up`

This approach allows:
- Consistent images across all deployments
- No need to compile anything on deployment machines
- Easy rollback by changing `IMAGE_TAG` in `.env`
- Multiple instances with different configurations from the same image

---

## Prerequisites

### For Building

* **Docker Engine** (≥ 24.x) installed
* **6-7 GB disk space** for building and staging
* **GitHub Container Registry (GHCR) credentials** (optional, only if pushing)

### For Deployment

* **Docker Engine** (≥ 24.x) installed
* **Docker Compose** (≥ v2.0) installed
* **2-3 GB disk space** for the image
* **Network access** to ghcr.io (if using public registry)

---

## Quick Start - Deployment

To deploy using a pre-built image:

1. **Clone or navigate to the repository:**
   ```bash
   git clone https://github.com/rydizz214/uhf-server-docker.git
   cd uhf-server-docker
   ```

2. **Create your configuration:**
   ```bash
   cp example.env .env
   # Edit .env to set your paths, ports, etc.
   nano .env
   ```

3. **Start the service:**
   ```bash
   docker-compose up -d
   ```

4. **Verify it's running:**
   ```bash
   docker-compose ps
   docker-compose logs -f
   ```

5. **Access UHF Server:**
   Open `http://localhost:8000` in your browser (or your configured `HOST_PORT`)

---

## Building & Pushing Images

> **Note:** This section is for maintainers building new versions. Most users will use the deployment instructions above.

To build and push a new version:

```bash
# Build locally
./build.sh

# Build without cache (forces fresh compile)
./build.sh --no-cache

# Build and push to GitHub Container Registry
./build.sh --push

# Build fresh and push (recommended for releases)
./build.sh --no-cache --push
```

The image will be tagged as `ghcr.io/rydizz214/uhf-server-docker:1.5.1`.

For detailed build instructions and authentication, see [DEPLOYMENT.md - Phase 1](./DEPLOYMENT.md#phase-1-build-and-push-one-time-setup).

---

## Environment Variables

Edit `.env` to customize your deployment.

### Image Configuration

```ini
# Container registry (where image is stored)
IMAGE_REGISTRY=ghcr.io/rydizz214/uhf-server-docker

# Image version/tag
IMAGE_TAG=1.5.1

# When to pull from registry: missing (default), always, or never
PULL_POLICY=missing
```

### Container Configuration

```ini
# Port inside container (usually 8000)
UHF_PORT=8000

# Port on your host machine
HOST_PORT=8000

# Where to store recordings
HOST_RECORDINGS_DIR=/data/recordings/uhf-server

# Where to store UHF database and data
HOST_UHF_DATA_DIR=/data/recordings/uhf-server

# Container timezone
TZ=America/New_York
```

### UHF Server Options

```ini
# Enable commercial detection (true/false)
UHF_ENABLE_COMMERCIAL_DETECTION=true

# Comskip arguments (--ini, --detectfiller, etc.)
COMSKIP_ARGS=--ini
```

---

## Running with Docker Compose

### Start the Service

```bash
docker-compose up -d
```

This will:
* Build the image if it doesn't exist
* Create a container named `uhf-server`
* Mount your recording and data directories
* Start UHF Server with commercial detection enabled
* Prevent system idle/sleep with systemd-inhibit

### Check Status

```bash
# View container status
docker-compose ps

# View logs in real-time
docker-compose logs -f

# View logs for specific lines
docker-compose logs --tail=50
```

### Stop the Service

```bash
docker-compose down
```

### Restart the Service

```bash
docker-compose restart
```

---

## Upgrading to a New Version

To use a new version of UHF Server or FFmpeg:

1. **A new image must be built and pushed** (by a maintainer):
   ```bash
   # Update Dockerfile with new versions
   # Then build and push
   ./build.sh --no-cache --push
   ```

2. **Update IMAGE_TAG in your .env** (on deployment machines):
   ```ini
   IMAGE_TAG=1.6.0  # New version
   ```

3. **Pull and restart**:
   ```bash
   docker-compose pull
   docker-compose down
   docker-compose up -d
   ```

### Check Installed Versions

```bash
# Check FFmpeg version
docker-compose exec uhf-server ffmpeg -version

# Check Comskip version
docker-compose exec uhf-server comskip --version

# Check which image is running
docker-compose ps
docker inspect uhf-server | grep Image
```

---

## Architecture

### Multi-Stage Build Process

```
┌─────────────────────┐
│  Stage 1: FFmpeg    │
│  - Build x264       │
│  - Build x265       │
│  - Build fdk-aac    │
│  - Build libvpx     │
│  - Build opus       │
│  - Build FFmpeg 8.0 │
└──────────┬──────────┘
           │
           ├─────────────────────────┐
           ↓                         ↓
   ┌───────────────┐      ┌──────────────────┐
   │ Stage 2: Comsk│      │ Stage 3: Runtime │
   │ - Build       │      │ - Add symlinks   │
   │   Comskip     │      │ - Download UHF   │
   └───────┬───────┘      │ - Copy FFmpeg    │
           │              │ - Copy Comskip   │
           │              │ - Add entrypoint │
           └──────────┬───┘
                      │
                      ↓
            ┌──────────────────┐
            │ Final Container  │
            │ - Ubuntu 25.04   │
            │ - FFmpeg 8.0     │
            │ - Comskip        │
            │ - UHF Server     │
            │ - systemd-inhibit│
            └──────────────────┘
```

### Dockerfile Organization

* **Dockerfile** - Multi-stage build (consolidated, replaces old Dockerfile and Dockerfile.inhibit)
* **entrypoint.sh** - Startup script that handles environment configuration
* **docker-compose.yml** - Container orchestration (single, consolidated file)
* **.env** - Version and configuration variables
* **example.env** - Template for environment variables

### entrypoint.sh Script

The `entrypoint.sh` script handles:
* Parsing environment variables
* Creating required directories
* Building UHF Server command with proper arguments
* Starting UHF with systemd-inhibit to prevent idle sleep
* Proper signal handling for graceful shutdown

---

## Troubleshooting

### Container fails to start

```bash
# Check logs for errors
docker-compose logs uhf-server

# Verify build completed successfully
docker-compose build --no-cache

# Check if directories exist and have correct permissions
ls -la /data/recordings/uhf-server
ls -la /var/lib/uhf-server
```

### Port already in use

Change `HOST_PORT` in `.env`:
```ini
HOST_PORT=8001  # Use different port
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

### Commercial detection not working

Verify Comskip is installed:
```bash
docker-compose exec uhf-server comskip --version
```

Check environment variable:
```bash
# Should be "true" or "1" in .env
UHF_ENABLE_COMMERCIAL_DETECTION=true
```

### Container is unhealthy

Wait a moment (healthcheck takes 10+ seconds on first start):
```bash
# Check health status
docker-compose ps

# Wait and check again
sleep 20
docker-compose ps

# View full logs
docker-compose logs --tail=100
```

### Out of disk space during build

FFmpeg source build is large. Ensure you have:
* **4GB+** available during build
* After build succeeds, space is cleaned up

### Permission denied errors

Ensure host directories are readable/writable:
```bash
sudo chown -R $(whoami):$(whoami) /data/recordings/uhf-server
sudo chown -R $(whoami):$(whoami) /var/lib/uhf-server
chmod -R 755 /data/recordings/uhf-server
chmod -R 755 /var/lib/uhf-server
```

---

## Advanced Usage

### Custom Comskip Configuration

Comskip config can be modified inside the container:
```bash
# Edit Comskip config
docker-compose exec uhf-server vi /usr/local/etc/comskip.ini

# Or copy your own config
docker cp ./my-comskip.ini uhf-server:/usr/local/etc/comskip.ini
```

### Manual FFmpeg Testing

```bash
# Test FFmpeg installation
docker-compose exec uhf-server ffmpeg -codecs | grep hevc

# Check FFmpeg build info
docker-compose exec uhf-server ffmpeg -version
```

### Accessing Container Shell

```bash
docker-compose exec uhf-server /bin/bash
```

---

## Full Documentation

For comprehensive information about this project:

- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete two-phase workflow guide
  - Phase 1: Building and pushing images
  - Phase 2: Deployment and configuration
  - Detailed build instructions
  - Registry authentication
  - Version management

---

## Support

For issues with UHF Server itself, visit: https://github.com/swapplications/uhf-server-dist

For Docker setup issues, check the logs and troubleshooting section above.

For deployment and configuration issues, see [DEPLOYMENT.md](./DEPLOYMENT.md).
