# Data Migration

 1. Get production database backup from
    [https://db-backups.renuo.ch/projects/143/databases/164](vdrb-kas) and
    [https://db-backups.renuo.ch/projects/144/databases/166](vdrb-mv)

 2. Restore backup:
    ```
    bin/restore_mv_kas_backup.sh
    ```

 3. Run import `bin/import.sh`
 4. Run dump_db `bin/dump_db.sh`
