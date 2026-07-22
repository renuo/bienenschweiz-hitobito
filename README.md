# bienenschweiz-hitobito

Combined wagon and composition repository for the Bienenschweiz Hitobito instance

## Environments

| Branch  | Domain                                             | Deployment |
| ------- | -------------------------------------------------- | ---------- |
| develop | https://bienenschweiz-hitobito-develop.renuoapp.ch | auto       |
| main    | TODO                                               | release    |


## Setup

See [./hitobito/doc/developer/local_setup.md](https://github.com/hitobito/hitobito/blob/master/doc/developer/local_setup.md)

`bin/setup` tries to automate this as much as possible.

### Inspection reminders

```
nctl exec app hitobito-main -p renuo-bienenschweiz bin/rails r 'InspectionReminderJob.perform_later'
```

The output will be sent to the logs. If some mails fail, it will log an error to Sentry and print out the indexes.
[The error will also be printed in the logs](app/services/inspection_service.rb#L58) so you can also inspect the logs.

The separate tasks can be run with

```
nctl exec app hitobito-main -p renuo-bienenschweiz bin/rails r 'InspectionService.new.retry_failed_inspection_reminder({{INDEX}})'
```

The index and command can be found in the logs or also Sentry (as extra argument `failed_index`).

## Running wagon tests

```sh
cd hitobito_bienenschweiz
bin/rspec
```

to reset the wagon test database, run

```sh
cd hitobito
rails db:drop db:create db:schema:load db:migrate wagon:migrate RAILS_ENV=test RAILS_TEST_DB_NAME=hit_bienenschweiz_test
```
