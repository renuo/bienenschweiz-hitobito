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

### KAS integration

The development seeds create an OAuth application and an API key (service token)
named `KAS`, both with randomly generated credentials. To instead reuse the
credentials a local KAS checkout already has in its `config/application.yml`
(`HITOBITO_OAUTH_ID`, `HITOBITO_OAUTH_SECRET` and `HITOBITO_API_KEY`), point
`KAS_PROJECT_PATH` at it via `.envrc`:

```sh
bundle exec rails db:seed wagon:seed
```

The seed is idempotent, so it can be re-run to switch between generated and
KAS-provided credentials. It prints both at the end.

### Exchange Online mailing list inbox

Register an Entra application with the **Office 365 Exchange Online** application
permission `IMAP.AccessAsApp` and grant admin consent. Register its service principal
in Exchange using the **Enterprise application** object ID, grant it `FullAccess`
to the dedicated mailbox, and enable IMAP on that mailbox.
[Microsoft’s app-only IMAP setup](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth#use-client-credentials-grant-flow-to-authenticate-smtp-imap-and-pop-connections)

Set these environment variables for the web app and delayed-jobs worker:

```yaml
RAILS_MAIL_RETRIEVER_TYPE: "imap"
RAILS_MAIL_RETRIEVER_CONFIG: >-
  address: outlook.office365.com, port: 993,
  user_name: 'mailingliste@bienenschweiz.ch'
BIENENSCHWEIZ_IMAP_TENANT_ID: "<directory tenant ID>"
BIENENSCHWEIZ_IMAP_CLIENT_ID: "<application client ID>"
BIENENSCHWEIZ_IMAP_CLIENT_SECRET: "<client secret value injected from the deployment secret store>"
```

The wagon uses TLS and obtains fresh access tokens as needed. To check IMAP
access from the deployed app, run:

```sh
bin/rails runner 'Imap::Connector.new.fetch_mail_uids(:inbox); puts "IMAP access OK"'
```

Run `bin/rails delayed_job:schedule` if the deployment hasn't already scheduled
`MailingLists::MailRetrieverJob`. Send a message from an authorized sender to a
test list and check delivery. The original list address must arrive in the
mailbox's `X-Original-To` header.

### Inspection reminders

```
nctl exec app hitobito-develop -p renuo-bienenschweiz bin/rails r 'InspectionReminderJob.new.enqueue!'
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
