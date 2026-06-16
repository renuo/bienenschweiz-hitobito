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
  direnv exec bin/rails mv:import:qcontrols
popd

echo "MV data imported. Now create a dump with bin/dump_db.sh and import it to the staging/production database."
