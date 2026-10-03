#!/usr/bin/env bash
set -euo pipefail

SRC=/Volumes/DATA/immich
DEST=${1:-/Volumes/COGATI-EXT/Immich-Backup}
KEEP_DB_DUMPS=14
DB_CONTAINER=immich_postgres
DB_USER=immich

[ -d "$SRC/library" ] || { echo "Sumber tidak ditemukan: $SRC/library" >&2; exit 1; }
mountpoint_root=$(echo "$DEST" | cut -d/ -f1-3)
[ -d "$mountpoint_root" ] || { echo "Disk tujuan belum ter-mount: $mountpoint_root" >&2; exit 1; }
docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null | grep -q true \
  || { echo "Container $DB_CONTAINER tidak jalan" >&2; exit 1; }

mkdir -p "$DEST/db" "$DEST/config"
STAMP=$(date +%F_%H%M)

echo "==> [1/3] Dump database"
DUMP="$DEST/db/immich-db-$STAMP.sql.gz"
docker exec -t "$DB_CONTAINER" pg_dumpall --clean --if-exists --username="$DB_USER" \
  | gzip > "$DUMP.tmp"
gzip -t "$DUMP.tmp"
mv "$DUMP.tmp" "$DUMP"
ls -t "$DEST"/db/immich-db-*.sql.gz | tail -n +$((KEEP_DB_DUMPS + 1)) | xargs -r rm -f

echo "==> [2/3] Sync library"
rsync -rltv --progress "$SRC/library/" "$DEST/library/"

echo "==> [3/3] Config"
cp "$SRC/docker-compose.yml" "$DEST/config/"
grep -vE '^(CLOUDFLARE_TUNNEL_TOKEN|NGROK_AUTHTOKEN)=' "$SRC/.env" > "$DEST/config/.env"

echo "==> Selesai: $DEST"
du -sh "$DEST"/db "$DEST"/library
