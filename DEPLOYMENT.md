# UHF Server Docker - Deployment Guide

This document describes the two-phase workflow for UHF Server Docker:

1. **Build Phase** - Build and push the Docker image to a registry (done once per version)
2. **Deployment Phase** - Deploy using docker-compose with personal configuration (done per instance)

## Overview

Unlike the previous setup where `docker-compose build` built the image locally every time, this new workflow separates concerns:

- **Image Building**: Happens once, produces a reusable Docker image pushed to a registry
- **Image Deployment**: Multiple machines can deploy the same pre-built image with different configurations

This is similar to how snappier-server and other professional Docker applications work.

## Phase 1: Build and Push (One-Time Setup)

### Prerequisites

- Docker Engine installed
- GitHub Container Registry (GHCR) access (for ghcr.io)
  - Requires GitHub account
  - Create a Personal Access Token (PAT) with `write:packages` scope
  - Or use GitHub Actions for automated builds

### Building the Image

From the uhf-server-docker directory:

```bash
# Basic build (image stays local)
./build.sh

# Build without cache (fresh compile)
./build.sh --no-cache

# Build and push to registry
./build.sh --push

# Build without cache and push
./build.sh --no-cache --push
```

### Authenticating with GitHub Container Registry

If pushing for the first time:

```bash
# Login to GitHub Container Registry
echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin
# Where CR_PAT is your GitHub Personal Access Token
```

### What Gets Built

The build process:

1. Compiles FFmpeg from source with codec support (x264, x265, VP9, opus, etc.)
2. Compiles Comskip from source for commercial detection
3. Downloads and installs UHF Server v1.5.1
4. Creates a self-contained image with all dependencies
5. Tags it as `ghcr.io/rydizz214/uhf-server-docker:1.5.1`

This image now contains everything needed to run - no additional build is required during deployment.

### Image Size

The final image is typically 2-3 GB due to:
- Ubuntu base image
- Compiled FFmpeg with multiple codecs
- Compiled Comskip
- UHF Server binary

## Phase 2: Deployment (Per Instance)

### Setup for Deployment

1. **Copy the deployment files** to your deployment machine:
   ```bash
   git clone https://github.com/rydizz214/uhf-server-docker.git
   cd uhf-server-docker
   ```

2. **Configure your environment** by creating/editing `.env`:
   ```bash
   cp example.env .env
   nano .env
   ```

3. **Customize the configuration** in `.env`:

   ```ini
   # Image Configuration
   IMAGE_REGISTRY=ghcr.io/rydizz214/uhf-server-docker
   IMAGE_TAG=1.5.1
   PULL_POLICY=missing

   # Container Configuration
   UHF_PORT=8000
   HOST_PORT=8000
   HOST_RECORDINGS_DIR=/data/recordings/uhf-server
   HOST_UHF_DATA_DIR=/data/recordings/uhf-server

   # UHF Server Options
   UHF_ENABLE_COMMERCIAL_DETECTION=true
   COMSKIP_ARGS=--ini
   TZ=America/New_York
   LOG_LEVEL=info
   ```

### Starting the Container

```bash
# Start in background
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f uhf-server

# Stop
docker-compose down
```

### Network Setup

If the image is in a private registry or not public:

```bash
# Authenticate with ghcr.io first
echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin

# Then start docker-compose
docker-compose up -d
```

## Configuration Per Instance

All deployment-specific settings are in `.env` and include:

| Variable | Purpose | Default |
|----------|---------|---------|
| `IMAGE_REGISTRY` | Container registry URL | `ghcr.io/rydizz214/uhf-server-docker` |
| `IMAGE_TAG` | Image version | `1.5.1` |
| `PULL_POLICY` | When to pull from registry | `missing` |
| `HOST_PORT` | Port on your host | `8000` |
| `HOST_RECORDINGS_DIR` | Where to store recordings | `/data/recordings/uhf-server` |
| `HOST_UHF_DATA_DIR` | Where to store UHF data | `/data/recordings/uhf-server` |
| `UHF_ENABLE_COMMERCIAL_DETECTION` | Enable Comskip | `true` |
| `COMSKIP_ARGS` | Comskip flags | `--ini` |
| `TZ` | Container timezone | `America/New_York` |
| `LOG_LEVEL` | Log verbosity | `info` |

## Updating to a New Version

### If UHF Server or FFmpeg Version Changes

1. **Update the Dockerfile** (in the build repository):
   - Change `ARG UHF_SERVER_VERSION=1.5.1` to new version
   - Change `ARG FFMPEG_VERSION=latest` if needed

2. **Build and push** the new image:
   ```bash
   ./build.sh --no-cache --push
   ```

3. **Update IMAGE_TAG in .env** (in deployment):
   ```ini
   IMAGE_TAG=1.6.0  # New version
   ```

4. **Pull and restart** on deployment machines:
   ```bash
   docker-compose pull
   docker-compose down
   docker-compose up -d
   ```

## Troubleshooting

### Image Pull Fails

```bash
# Check authentication
docker login ghcr.io -u USERNAME --password-stdin

# Force pull latest
docker-compose pull --ignore-pull-failures

# Or specify a different registry if needed
IMAGE_REGISTRY=your-registry docker-compose up -d
```

### Container Won't Start

```bash
# Check logs
docker-compose logs --tail=100

# Verify directories exist
ls -la /data/recordings/uhf-server

# Check permissions
chmod -R 755 /data/recordings/uhf-server
```

### Out of Disk Space

The first pull may require significant space:
- Image size: ~2-3 GB
- Extracted layers: Additional ~2-3 GB during extraction
- Running container: ~500 MB - 1 GB for data

Ensure you have **at least 6-7 GB free** on first deployment.

## Advantages of This Setup

1. **Consistency**: Same image across all deployments
2. **Efficiency**: Image is built once, deployed many times
3. **Version Control**: Easy to track which image version is running where
4. **Scalability**: Can run multiple containers from the same image
5. **CI/CD Ready**: Can integrate with GitHub Actions for automated builds
6. **Separation of Concerns**: Image creation separate from configuration

## For Development

If you need to modify the Dockerfile:

1. Update the Dockerfile
2. Rebuild locally: `./build.sh --no-cache`
3. Test with docker-compose: `docker-compose up -d`
4. When satisfied, push: `./build.sh --push`

## Related Files

- `Dockerfile` - Multi-stage build definition
- `entrypoint.sh` - Startup script
- `docker-compose.yml` - Deployment configuration
- `.env` / `example.env` - Environment variables
- `build.sh` - Build and push script

