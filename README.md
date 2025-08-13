# UHF Server Docker Setup

This directory contains Docker configuration files to easily run the UHF DVR Server.

## Requirements

- Docker and Docker Compose installed on your system
- Sufficient disk space for recordings

## Quick Start

1. Clone this repository or download these files
2. Run the server with default settings:

```bash
docker-compose up -d
```

This will:
- Build the Docker image with all dependencies
- Start the UHF Server on port 8000
- Store recordings in a `./recordings` directory

## Configuration

You can customize the server by setting environment variables:

```bash
# Set custom port and recordings directory
PORT=9000 RECORDINGS_DIR=/path/to/recordings docker-compose up -d

# Add password protection
PORT=8000 RECORDINGS_DIR=/path/to/recordings PASSWORD=mysecretpassword docker-compose up -d
```

### Available Options

- `PORT`: Server port (default: 8000)
- `RECORDINGS_DIR`: Path to store recordings (default: ./recordings)
- `PASSWORD`: Optional password protection


## Logs and Troubleshooting

View logs:
```bash
docker-compose logs -f
```

## Stopping the Server

```bash
docker-compose down
```

## Using the dockerhub image
```bash
docker run -d --init --name=uhf --restart unless-stopped \
-v /mnt/mydisk/recordings:/recordings \
-p 8000:8000 \
swapplications/uhf-server:1.5.1 \
uhf-server --port 8000 --recordings-dir /recordings
```

Replace `/mnt/mydisk/recordings` with a valid path to your recordings directory.
