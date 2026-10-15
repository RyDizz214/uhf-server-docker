# UHF Server — Docker

A ready-to-run Docker setup for [UHF Server](https://github.com/swapplications/uhf-server-dist),
the DVR server for the UHF app. It records live streams on schedule, detects commercials with
Comskip, and serves recordings to the UHF apps and to its own web app.

The pre-built image is published to GitHub Container Registry for Intel/AMD (`amd64`) and ships:

* **UHF Server 2.2.0**
* **FFmpeg 9.0.2**, built from source with x264, x265, fdk-aac, libvpx and opus
* **Comskip 0.83**, built from source for commercial detection
* **Ubuntu 26.04 LTS** base

See [CHANGELOG.md](CHANGELOG.md) for what's new in UHF Server.

Compared with the official `swapplications/uhf-server` image, this one adds a newer FFmpeg,
configuration through `.env`, an optional VPN overlay that works with any provider, and an
optional overlay that uses the host's ffmpeg instead of the bundled one.

---

## Install

### 1. Install Docker on your Linux host

If you don't already have it: <https://docs.docker.com/engine/install/>.
Docker Compose v2 is included with modern Docker installs.

### 2. Get the files

```bash
git clone https://github.com/rydizz214/uhf-server-docker.git
cd uhf-server-docker
cp example.env .env
```

### 3. Set a password and start it

Edit `.env` and set `UHF_PASSWORD`. Without one, anyone who can reach the server can use it
and open the web app without signing in. Then:

```bash
docker compose up -d
```

### 4. Connect

* **UHF apps:** Settings → DVR server, then enter the address of the machine running Docker and
  the port (`HOST_PORT`, default 8000).
* **Web app:** open `http://<address>:<port>/` in a browser to manage scheduled recordings,
  browse and download the library, watch recordings (including ones still in progress), and
  follow the server log live.

---

## Common settings

All settings live in `.env`. See [example.env](example.env) for the full list.

| Variable | Default | What it does |
|----------|---------|--------------|
| `UHF_PASSWORD` | none | Password the apps and the web app must present. Changing it ends existing web sessions. |
| `HOST_PORT` | `8000` | Port on the host. |
| `HOST_RECORDINGS_DIR` | `./uhf-recordings` | Where recordings are stored on the host. |
| `HOST_UHF_DATA_DIR` | `./uhf-data` | Where the server database is stored on the host. Keep it, or schedules are lost. |
| `UHF_ENABLE_COMMERCIAL_DETECTION` | `true` | Run Comskip on each finished recording so the apps can skip ad breaks. |
| `UHF_SINGLE_FILE_RECORDINGS` | `false` | Merge each finished recording into one `index.ts`. Playback and downloads are unchanged. The merge briefly needs twice the recording's size in free disk space. |
| `TZ` | `America/New_York` | Time zone, used for recurring recordings. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warning`, `error` or `critical`. |
| `IMAGE_TAG` | `2.2.0` | Image version to run. |

Recordings are stored as HLS, one folder per recording. Each folder holds an `index.m3u8`
playlist, its segments (or a single `index.ts`), the Comskip cut list, a thumbnail and an
`ffmpeg.log`. If a recording fails, attach its `ffmpeg.log` to your bug report.

---

## Add a VPN (optional)

To route all of UHF Server's traffic through a VPN, use the gluetun overlay.
[gluetun](https://github.com/qdm12/gluetun) supports 40+ providers, including NordVPN, Mullvad,
ProtonVPN, PIA, Surfshark, AirVPN and Windscribe.

1. Add your VPN settings to `.env`. Example for Mullvad over WireGuard:

   ```env
   VPN_SERVICE_PROVIDER=mullvad
   VPN_TYPE=wireguard
   WIREGUARD_PRIVATE_KEY=<paste-your-key>
   WIREGUARD_ADDRESSES=<address-from-your-provider>
   SERVER_COUNTRIES=Sweden
   ```

   The exact variables for your provider are in the
   [gluetun wiki](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers). Every
   variable in `.env` is passed to gluetun, so any gluetun setting works without editing the
   compose files.

2. Start with the overlay:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.vpn.yml up -d
   ```

   Or set `COMPOSE_FILE=docker-compose.yml:docker-compose.vpn.yml` in `.env` so a plain
   `docker compose up -d` includes it.

With the VPN overlay the port is bound to `127.0.0.1` only. Put a reverse proxy in front of it
for access from other devices.

---

## Use the host's ffmpeg (optional, x86-64 only)

If your host has its own ffmpeg (for example a GPU-accelerated or newer build), the
`docker-compose.host-ffmpeg.yml` overlay uses the host's `ffmpeg`, `ffprobe` and `comskip`
instead of the bundled ones:

```bash
docker compose -f docker-compose.yml -f docker-compose.host-ffmpeg.yml up -d
```

It mounts the host's libraries read-only and runs each binary through the host's own dynamic
loader, so the host's and container's glibc versions don't need to match. It expects
`/usr/bin/ffmpeg`, `/usr/bin/ffprobe` and `/usr/local/bin/comskip` on the host; edit the
overlay if yours are elsewhere. Overlays combine, for example
`COMPOSE_FILE=docker-compose.yml:docker-compose.vpn.yml:docker-compose.host-ffmpeg.yml`.

---

## Commands

```bash
docker compose ps                  # status
docker compose logs -f uhf-server  # follow the log
docker compose pull && docker compose up -d   # update to the IMAGE_TAG in .env
docker compose down                # stop
```

Check versions inside the container:

```bash
docker compose exec uhf-server ffmpeg -version
docker compose exec uhf-server sh -c 'comskip 2>&1 | head -1'
curl -s http://localhost:8000/server/stats   # includes the UHF Server version
```

---

## Troubleshooting

**The container exits right away.** Run `docker compose logs uhf-server`. The startup banner
shows the settings it was started with.

**The apps can't find the server.** Check that `HOST_PORT` is reachable from the device and
not blocked by a firewall. With the VPN overlay the port is bound to `127.0.0.1` only.

**Recurring recordings land on the wrong day.** Set `TZ` to your local time zone. Series
scheduled from older UHF app versions keep using UTC; re-create them from an up-to-date app.

**A recording fails with "connections in use".** Your playlist's simultaneous-connection
limit is reached, usually because another device is still playing a channel from it.

**Commercial detection doesn't run.** Make sure `UHF_ENABLE_COMMERCIAL_DETECTION=true`.
Detection starts when a recording finishes and takes a few minutes.

**Keep the host awake during recordings.** Uncomment the D-Bus socket mount in
`docker-compose.yml`. The container then wraps the server in `systemd-inhibit`. Without that
mount it starts normally, without sleep prevention.

---

## Building the image

Maintainers only; everyone else uses the published image.

```bash
./build.sh               # build locally
./build.sh --no-cache    # fresh build
./build.sh --push        # build and push to ghcr.io (needs `docker login ghcr.io`)
```

Versions are set by build arguments in the [Dockerfile](Dockerfile): `UHF_SERVER_VERSION`,
`FFMPEG_VERSION`, `X265_VERSION`, `COMSKIP_VERSION` and `COMSKIP_FFMPEG_VERSION`. The image
tag is set in [build.sh](build.sh).

The build has three stages:

1. **FFmpeg:** x264, x265, fdk-aac, libvpx and opus, then FFmpeg itself.
2. **Comskip:** Comskip 0.83 uses an API that FFmpeg 8 removed, so it is linked statically
   against a small, decode-only FFmpeg 7.1. It doesn't need Ubuntu's FFmpeg at runtime.
3. **Runtime:** Ubuntu 26.04 with the compiled tools, the UHF Server release zip and
   `entrypoint.sh`, which turns the `.env` settings into server arguments.

---

## Support

* UHF Server itself: <https://github.com/swapplications/uhf-server-dist>
* This Docker setup: <https://github.com/rydizz214/uhf-server-docker>

## License

See [LICENSE](LICENSE).
