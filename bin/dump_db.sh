#!/usr/bin/env bash

set -euo pipefail

git submodule update --init

pushd hitobito
  direnv exec bin/rails db:migrate wagon:migrate
popd

pg_dump hit_bienenschweiz_dev --no-acl --no-owner --schema-only --clean > dump.sql
pg_dump hit_bienenschweiz_dev --data-only >> dump.sql

echo "Now import"
echo "psql -h hitobito-develop.8a5926d.db.postgres.nineapis.ch -d 1c62958_d4d57b3 -U 1c62958_d4d57b3 < dump.sql"
