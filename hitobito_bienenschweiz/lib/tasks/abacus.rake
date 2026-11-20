# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

namespace :abacus do
  desc "Create the Abacus subject (contact, address, customer) for every person with an " \
       "active role or magazine subscription that is not linked to Abacus yet.\n" \
       "Usage: rake abacus:create_missing_subjects[dry_run] (pass 'dry_run' to only list them)"
  task :create_missing_subjects, [:dry_run] => :environment do |_, args|
    abort "Abacus is not configured (Settings.abacus)" unless Invoices::Abacus::Config.exist?

    people = Invoices::Abacus::CreateMissingSubjects.people
    puts "#{people.count} people without Abacus subject"

    if args[:dry_run] == "dry_run"
      people.find_each { |person| puts "#{person.id} #{person}" }
      next
    end

    result = Invoices::Abacus::CreateMissingSubjects.new(logger: method(:puts)).run
    puts "Created/linked: #{result.created.size}, failed: #{result.failed.size}"
  end

  desc "Export the links between hitobito and Abacus (person subject keys, invoice sales " \
       "order keys) as JSON, to transfer them to another instance sharing the Abacus mandant.\n" \
       "Usage: rake abacus:export_mapping[path]"
  task :export_mapping, [:path] => :environment do |_, args|
    path = args[:path].presence || "abacus_mapping.json"
    data = Invoices::Abacus::KeyMapping.export
    File.write(path, JSON.pretty_generate(data))
    puts "Exported #{data[:people].size} people and #{data[:external_invoices].size} " \
         "invoices to #{path}"
  end

  desc "Import links exported with abacus:export_mapping. People are matched by id and " \
       "name, invoices by subscription and period; mismatches are skipped.\n" \
       "Usage: rake abacus:import_mapping[path,dry_run]"
  task :import_mapping, [:path, :dry_run] => :environment do |_, args|
    abort "Usage: rake abacus:import_mapping[path,dry_run]" if args[:path].blank?

    dry_run = args[:dry_run] == "dry_run"
    result = Invoices::Abacus::KeyMapping.new(
      JSON.parse(File.read(args[:path])), dry_run:, logger: method(:puts)
    ).import
    puts "#{"[DRY RUN] " if dry_run}Imported #{result.people} people, " \
         "#{result.invoices} invoices, skipped #{result.skipped.size}"
  end

  desc "Run the magazine subscription invoicing now instead of waiting for the nightly job. " \
       "The run and its errors are shown under Admin > Rechnungsläufe.\n" \
       "Usage: rake abacus:create_magazine_subscription_invoices[max_requests_per_minute,limit] " \
       "(max_requests_per_minute overrides ABACUS_MAX_REQUESTS_PER_MINUTE, 0 = unlimited; " \
       "limit only invoices the first n due subscriptions)"
  task :create_magazine_subscription_invoices,
    [:max_requests_per_minute, :limit] => :environment do |_, args|
    abort "Invoicing is disabled (MAGAZINE_SUBSCRIPTION_INVOICING_ENABLED)" unless
      Settings.magazine_subscription_invoicing.enabled

    if args[:max_requests_per_minute].present?
      Settings.abacus.max_requests_per_minute = args[:max_requests_per_minute].to_i
    end
    rate = Invoices::Abacus::Config.max_requests_per_minute
    puts "Max requests per minute: #{rate || "unlimited"}"

    last_id = ExternalInvoiceRun.maximum(:id).to_i
    started = Time.current
    limit = args[:limit].presence&.to_i
    Invoices::Abacus::CreateMagazineSubscriptionInvoicesJob.new.perform_internal(limit:)
    run = ExternalInvoiceRun.find_by("id > ?", last_id)
    puts(run ? "#{run}: #{run.state_label}, #{run.created_count} created, " \
               "#{run.error_count} errors" : "No subscriptions due")
    puts "Duration: #{(Time.current - started).round}s"
  end
end
