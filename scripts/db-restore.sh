#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
  echo "❌ Usage: $0 <backup-folder>"
  exit 1
fi

docker cp $1 mongo:/data/db-restore
docker exec mongo mongorestore --db fullstack_app --drop /data/db-restore/fullstack_app

echo "✅ Restore complete from $1"
