#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="backups/mongo_$TIMESTAMP"

mkdir -p $BACKUP_DIR
docker exec mongo mongodump --db fullstack_app --out /data/db-dump
docker cp mongo:/data/db-dump $BACKUP_DIR

echo "✅ Backup complete: $BACKUP_DIR"
