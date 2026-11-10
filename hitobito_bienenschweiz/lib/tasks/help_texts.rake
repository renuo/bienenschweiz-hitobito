# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Help texts are identified by their natural key (controller, model, kind, name), not by
# id, so the YAML stays diffable and can be loaded into any database.
namespace :help_texts do
  def help_text_key_columns = %w[controller model kind name]

  desc "Dump help texts and their translated bodies as YAML to stdout"
  task export: :environment do
    data = HelpText.unscoped.includes(translations: :rich_text_body).to_a
      .sort_by { |help_text| help_text_key_columns.map { |col| help_text[col].to_s } }
      .map do |help_text|
        bodies = help_text.translations.select(&:rich_text_body).sort_by(&:locale)
          .to_h do |translation|
            [translation.locale.to_s,
              translation.rich_text_body.read_attribute_before_type_cast(:body)]
          end
        help_text.attributes.slice(*help_text_key_columns, "start_open").merge("body" => bodies)
      end

    puts({"help_texts" => data}.to_yaml)
  end

  desc "Load help texts from YAML (path or stdin), replacing all existing help texts"
  task :import, [:path] => :environment do |_, args|
    require "yaml"

    input = args[:path] ? File.read(args[:path]) : $stdin.read
    entries = YAML.safe_load(input).fetch("help_texts", [])

    ActiveRecord::Base.transaction do
      kept_ids = entries.map do |entry|
        bodies = entry.fetch("body").compact_blank
        key = entry.slice(*help_text_key_columns)
        help_text = HelpText.unscoped.find_or_initialize_by(key)
        if help_text.new_record?
          # HelpText derives these columns from context/key before validating new records
          help_text.context = [key["controller"], key["model"]].join("--")
          help_text.key = [key["kind"], key["name"]].join(".")
        end
        help_text.start_open = entry.fetch("start_open", false)

        bodies.each do |locale, html|
          Globalize.with_locale(locale) { help_text.body = html }
        end
        Globalize.with_locale(bodies.keys.first) { help_text.save! }

        # The rich text body is set on the translation directly, which globalize does not
        # autosave, so persist the translations ourselves (see HelpTextsController#save_entry)
        help_text.translations.each do |translation|
          if bodies.key?(translation.locale.to_s)
            translation.help_text_id = help_text.id
            translation.save!
          else
            translation.destroy!
          end
        end
        help_text.id
      end

      HelpText.unscoped.where.not(id: kept_ids).destroy_all
    end

    warn "Imported #{entries.size} help texts."
  end
end
