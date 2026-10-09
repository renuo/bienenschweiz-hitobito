#!/usr/bin/env bash

set -euo pipefail

git submodule update --init

pushd hitobito
  direnv exec bin/rails db:migrate wagon:migrate
popd

pg_dump hit_bienenschweiz_dev --no-acl --no-owner --schema-only --clean > dump.sql
pg_dump hit_bienenschweiz_dev --data-only --exclude-table=delayed_jobs >> dump.sql

echo "Before importing, make sure INTEGRATIONS_JSON of the target app is current (OAuth apps / API keys"
echo "created there since the last import are wiped otherwise). Compare it with the output of:"
echo "nctl exec app hitobito-develop -p renuo-bienenschweiz -- bundle exec rake integrations:dump"
echo
echo "Now import"
echo "psql -h hitobito-develop.8a5926d.db.postgres.nineapis.ch -d 1c62958_d4d57b3 -U 1c62958_d4d57b3 < dump.sql"
echo
echo "Then recreate the OAuth apps and API keys"
echo "nctl exec app hitobito-develop -p renuo-bienenschweiz -- bundle exec rake integrations:restore"
