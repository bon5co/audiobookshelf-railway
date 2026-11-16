#!/bin/sh
# Audiobookshelf on Railway: root user from ADMIN_PASSWORD before the server is reachable, libraries on the volume.
# Phase 1 runs the server on 127.0.0.1:3333 only, so nothing outside the container can call /init first.
# Phase 2 execs the real server on Railway's injected PORT.
set -eu

die() { echo "audiobookshelf-railway: $*" >&2; exit 1; }

[ -n "${ADMIN_PASSWORD:-}" ] || die "ADMIN_PASSWORD is empty - the server would stay open to the first visitor"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || die "ADMIN_PASSWORD must be at least 12 characters"
case "$ADMIN_PASSWORD" in *[!A-Za-z0-9._~-]*) die "ADMIN_PASSWORD may only contain letters, digits and . _ ~ -" ;; esac

ADMIN_USERNAME=root
LOCAL=http://127.0.0.1:3333
JSON="Content-Type: application/json"

mkdir -p /data/config /data/metadata /data/audiobooks /data/podcasts
echo "audiobookshelf-railway: /data owner=$(stat -c %u:%g /data) port=${PORT:-unset}"

# phase 1: loopback only
PORT=3333 HOST=127.0.0.1 "$@" >/tmp/abs-phase1.log 2>&1 &
SRV=$!

n=0
until wget -qO /tmp/status.json "$LOCAL/status" 2>/dev/null; do
  n=$((n+1)); [ "$n" -le 120 ] || { cat /tmp/abs-phase1.log >&2; die "server did not answer on loopback"; }
  kill -0 "$SRV" 2>/dev/null || { cat /tmp/abs-phase1.log >&2; die "server exited during boot"; }
  sleep 1
done

if grep -q '"isInit":false' /tmp/status.json; then
  wget -qO /dev/null --header="$JSON" --post-data="{\"newRoot\":{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}}" "$LOCAL/init" || die "root user creation failed"
  echo "audiobookshelf-railway: root user created"
fi

TOKEN="$(wget -qO- --header="$JSON" --post-data="{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" "$LOCAL/login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -1)" || true
[ -n "$TOKEN" ] || die "root login with ADMIN_PASSWORD failed - the volume holds a different root password"

LIBS="$(wget -qO- --header="Authorization: Bearer $TOKEN" "$LOCAL/api/libraries")"
case "$LIBS" in *'"id"'*) echo "audiobookshelf-railway: libraries already exist" ;; *)
  wget -qO /dev/null --header="Authorization: Bearer $TOKEN" --header="$JSON" --post-data='{"name":"Audiobooks","mediaType":"book","folders":[{"fullPath":"/data/audiobooks"}]}' "$LOCAL/api/libraries" || die "creating Audiobooks library failed"
  wget -qO /dev/null --header="Authorization: Bearer $TOKEN" --header="$JSON" --post-data='{"name":"Podcasts","mediaType":"podcast","folders":[{"fullPath":"/data/podcasts"}]}' "$LOCAL/api/libraries" || die "creating Podcasts library failed"
  echo "audiobookshelf-railway: libraries created" ;;
esac

kill "$SRV" 2>/dev/null || true
wait "$SRV" 2>/dev/null || true

# phase 2: the real listener (Railway injects PORT)
unset HOST
echo "audiobookshelf-railway: starting on port ${PORT:-80}"
exec "$@"
