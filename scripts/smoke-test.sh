#!/bin/bash
# Smoke-test a UHF Server image: start it, check the API and password,
# then exercise ffmpeg (x264, x265) and Comskip inside the container.
#
# Usage: scripts/smoke-test.sh <image> [host-port]
set -euo pipefail

IMAGE="${1:?usage: $0 <image> [host-port]}"
PORT="${2:-18080}"
NAME="uhf-smoke-$$"
TMP="$(mktemp -d)"

cleanup() {
    docker rm -f "${NAME}" >/dev/null 2>&1 || true
    rm -rf "${TMP}" 2>/dev/null || true
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; docker logs "${NAME}" 2>&1 | tail -30 >&2 || true; exit 1; }

echo "== Starting ${IMAGE}"
docker run -d --init --name "${NAME}" \
    -p "127.0.0.1:${PORT}:8000" \
    -e UHF_PASSWORD=smoke-test \
    -e UHF_SINGLE_FILE_RECORDINGS=true \
    -v "${TMP}/recordings:/recordings" \
    -v "${TMP}/data:/var/lib/uhf-server" \
    "${IMAGE}" >/dev/null

echo "== Architecture: $(docker exec "${NAME}" uname -m)"

STATS=""
for _ in $(seq 1 60); do
    STATS="$(curl -fsS -m 5 "http://127.0.0.1:${PORT}/server/stats" 2>/dev/null)" && break
    [ "$(docker inspect -f '{{.State.Running}}' "${NAME}")" = "true" ] || fail "container exited"
    sleep 2
done
[ -n "${STATS}" ] || fail "server did not answer /server/stats within 120s"

python3 - "${STATS}" <<'EOF' || fail "stats check"
import json, sys
d = json.loads(sys.argv[1])
print(f"== UHF Server {d['version']}: ffmpeg={d['ffmpeg_available']} comskip={d['comskip_available']}")
assert d["ffmpeg_available"] and d["comskip_available"], "ffmpeg or comskip unavailable"
EOF

CODE="$(curl -s -m 5 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    -d '{"password":"wrong","device_id":"smoke-test"}' "http://127.0.0.1:${PORT}/auth/password-login")"
[ "${CODE}" = "401" ] || fail "wrong password returned HTTP ${CODE}, expected 401"
echo "== Password enforced (wrong password -> 401)"

docker logs "${NAME}" 2>&1 | grep -q -- 'Single-File Recordings: true' || fail "single-file option not applied"

echo "== ffmpeg: $(docker exec "${NAME}" ffmpeg -version | head -1)"
docker exec "${NAME}" ffmpeg -v error -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440 \
    -t 20 -c:v libx264 -preset veryfast -c:a aac -f mpegts /tmp/smoke-x264.ts || fail "x264 encode"
docker exec "${NAME}" ffmpeg -v error -f lavfi -i testsrc2=size=640x360:rate=30 \
    -t 3 -c:v libx265 -preset ultrafast -f mpegts /tmp/smoke-x265.ts || fail "x265 encode"
echo "== x264 and x265 encodes OK"

# Comskip exits 0 when it finds commercials and 1 when it finds none; anything else is an error.
set +e
docker exec "${NAME}" sh -c 'cd /tmp && comskip --quiet /tmp/smoke-x264.ts >/tmp/comskip.log 2>&1'
RC=$?
set -e
[ "${RC}" -le 1 ] || { docker exec "${NAME}" tail -20 /tmp/comskip.log >&2; fail "comskip exited ${RC}"; }
echo "== Comskip OK (exit ${RC})"

echo "PASS: ${IMAGE}"
