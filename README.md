# UHF Server Docker Setup

This repository contains the Docker configuration files to run the UHF DVR Server, the release
zips for Linux (see [Releases](https://github.com/swapplications/uhf-server-dist/releases)) and
the [changelog](CHANGELOG.md).

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
- Pull the `swapplications/uhf-server` image from Docker Hub
- Start the UHF Server on port 8000, with commercial detection enabled
- Store recordings in `./uhf-recordings` and the server database in `./uhf-db`

Then add the server in UHF (Settings → DVR server) with the address of the machine running
Docker and the port, or open `http://<address>:<port>/` in a browser for the management web app
(scheduled recordings, library, in-browser playback, logs).

## Configuration

`docker-compose.yml` reads two variables, either from the environment or from a `.env` file
(copy `example.env` to `.env` to get started):

```bash
# Set a custom port
PORT=9000 docker-compose up -d

# Add password protection
PORT=8000 PASSWORD=mysecretpassword docker-compose up -d
```

- `PORT`: Server port (default: 8000)
- `PASSWORD`: Optional password protection. Without it, anyone on your network can use the
  server and the web app opens without signing in.

To change anything else (recordings location, single-file recordings, log level, ...) edit the
`command:` line of `docker-compose.yml` using the arguments below, or run the image directly as
shown in [Using the Docker Hub image](#using-the-docker-hub-image).

## Server arguments

The container runs the `uhf-server` binary. Every option can be given as a command-line argument
or as an environment variable (the argument wins when both are set); booleans accept `true`/`false`.

| Argument | Environment variable | Default | Description |
|----------|---------------------|---------|-------------|
| `--host <address>` | `API_HOST` | `0.0.0.0` | Address to listen on. Keep the default inside Docker so the port mapping works. |
| `--port <port>` | `API_PORT` | `8000` | Port of the API and the web app. Must match the published port in `docker-compose.yml` or `-p`. |
| `--recordings-dir <path>` | `RECORDINGS_DIR` | `/var/lib/uhf-server/recordings` | Where recordings are stored, one folder per recording. In the compose file this is the `/recordings` volume. |
| `--db-path <file>` | `DB_PATH` | `/var/lib/uhf-server/db.json` | The server database (schedules, recording states, web sessions). Keep it on a volume so schedules survive container updates; the compose file mounts `./uhf-db` at `/var/lib/uhf-server`. |
| `--password <password>` | `SERVER_PASSWORD` | none | Password the apps and the web app must present. Changing it ends existing web sessions. |
| `--enable-commercial-detection` | `ENABLE_COMMERCIAL_DETECTION` | `false` | Run Comskip on every finished recording so the apps and the web app can skip ad breaks. Takes a few minutes per recording and some CPU. The compose file enables it. |
| `--single-file-recordings` | `SINGLE_FILE_RECORDINGS` | `false` | When a recording finishes, merge its segments into a single `index.ts` file in the recording folder (the playlist is kept, so playback and downloads are unchanged). The merge briefly needs twice the recording's size on disk. |
| `--ffmpeg-path <file>` | `FFMPEG_PATH` | `ffmpeg` from `PATH` | ffmpeg executable to use (7.x or newer). The image ships Ubuntu's ffmpeg. |
| `--comskip-path <file>` | `COMSKIP_PATH` | `comskip` from `PATH` | Comskip executable to use. The image builds Comskip from source at `/usr/local/bin/comskip`. |
| `--log-level <level>` | `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR` or `CRITICAL`. |
| `-h`, `--help` | | | Print the list of arguments. |

Recordings are stored as HLS: a folder per recording with an `index.m3u8` playlist, 4-second
segments (or a single `index.ts` with `--single-file-recordings`), the Comskip cut list, a
thumbnail and an `ffmpeg.log` with the output of every ffmpeg attempt, which is the first thing
to attach to a bug report.

## Logs and Troubleshooting

View logs:
```bash
docker-compose logs -f
```

The web app at `http://<address>:<port>/` also shows the server log live, with level and text
filters.

## Stopping the Server

```bash
docker-compose down
```

## Using the Docker Hub image

```bash
docker run -d --init --name=uhf --restart unless-stopped \
-v /mnt/mydisk/recordings:/recordings \
-v /mnt/mydisk/uhf-db:/var/lib/uhf-server \
-p 8000:8000 \
swapplications/uhf-server:2.2.1 \
uhf-server --port 8000 --recordings-dir /recordings --enable-commercial-detection
```

Replace `/mnt/mydisk/recordings` and `/mnt/mydisk/uhf-db` with valid paths on your system, and
append any of the [server arguments](#server-arguments), for example `--password mysecretpassword`
or `--single-file-recordings`. Version tags are published for every release, and `latest` points at the newest one (2.2.1 onwards).

## Running without Docker

The Linux release zips (`UHF.Server-linux-x64-<version>.zip`, `UHF.Server-linux-arm64-<version>.zip`)
contain the same `uhf-server` binary. Install the latest one with:

```bash
curl -sL https://link.uhfapp.com/setup.sh | bash
```

The script needs `unzip` and ffmpeg 7.x or newer, builds Comskip from source when it is missing,
installs the server to `/opt/uhf-server` and links the `uhf-server` command into `/usr/local/bin`.
Run it with the arguments above, for example:

```bash
uhf-server --port 8000 --recordings-dir /srv/recordings --db-path /srv/uhf/db.json --enable-commercial-detection
```
