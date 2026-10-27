#!/bin/bash

set -euo pipefail

git fetch --all --prune

if ! git merge-base --is-ancestor origin/develop HEAD; then
  echo "Error: Your local branch is not up-to-date with origin/develop."
  exit 1
fi

git submodule update --init

pushd hitobito
  direnv exec bin/rails db:drop db:create db:migrate wagon:migrate db:seed wagon:seed NO_ENV=1
popd

pushd hitobito_bienenschweiz
  direnv exec bin/rails mv:import:groups
  direnv exec bin/rails mv:import:members
  direnv exec bin/rails mv:import:roles
  export RAILS_STORAGE_SERVICE=cloudscale
  direnv exec bin/rails mv:import:quality_controls
  direnv exec bin/rails mv:import:supervisions
  direnv exec bin/rails mv:import:documents
  direnv exec bin/rails mv:import:memos
  direnv exec bin/rails mv:import:fees
  direnv exec bin/rails "mv:import:siegelimker_profiles[../hitobito_bienenschweiz/siegelimker-2026-10-23-145302.csv]"
  bundle exec rake "mv:import:magazine_subscriptions[../hitobito_bienenschweiz/export_abo.csv,../hitobito_bienenschweiz/invalid_members.csv]"
  direnv exec bin/rails mv:import:reset_id_sequences
popd

echo "MV data imported. Now create a dump with bin/dump_db.sh and import it to the staging/production database."
