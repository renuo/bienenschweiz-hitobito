#!/bin/bash

set -euo pipefail

git submodule update --init

pushd hitobito
  direnv exec bin/rails db:drop db:create db:migrate wagon:migrate db:seed wagon:seed NO_ENV=1
popd

pushd hitobito_bienenschweiz
  direnv exec bin/rails mv:import:groups
  direnv exec bin/rails mv:import:members
  direnv exec bin/rails mv:import:roles
popd

echo "MV data imported. Now create a dump with bin/dump_db.sh and import it to the staging/production database."
