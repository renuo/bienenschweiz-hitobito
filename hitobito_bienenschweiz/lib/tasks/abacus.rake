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
end
