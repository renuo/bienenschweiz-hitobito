#!/bin/bash

set -euo pipefail

pw=$(op item get db-backups-key-production-main --reveal --fields password)

for app in vdrb-mv vdrb-kas; do
  db_name="${app}_development"
  dump_file="$(date --iso)-${app}.dump.enc"
  cat $dump_file |
    openssl aes-256-cbc -md sha256 -iter 20000 -pass pass:$pw -salt -pbkdf2 -d |
    mysql $db_name 
done
