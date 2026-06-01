# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


# TODO: These tasks are only needed for the migration process. Can be deleted
# after the migration.
namespace :courses do
  def export_models = [Event::KindCategory, Event::Kind, QualificationKind]

  desc "Dump course kinds, categories and qualifications as YAML to stdout"
  task export: :environment do
    data = {}

    export_models.each do |klass|
      data[klass.table_name] = klass.unscoped.order(:id).map do |record|
        attrs = record.attributes.slice(*klass.column_names)
        attrs["translations"] = record.translations
          .unscope(:order)
          .order(:locale)
          .map { |t| t.attributes.slice(*klass.translation_class.column_names) }
        attrs
      end
    end

    data[Event::KindQualificationKind.table_name] =
      Event::KindQualificationKind.unscoped.order(:id).map do |record|
        record.attributes.slice(*Event::KindQualificationKind.column_names)
      end

    puts data.to_yaml
  end

  desc "Load YAML from stdin and replace course kinds, categories and qualifications"
  task import: :environment do
    require "yaml"

    data = YAML.safe_load(
      $stdin.read,
      permitted_classes: [Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
        BigDecimal, Symbol],
      aliases: true
    )

    ActiveRecord::Base.transaction do
      Event::KindQualificationKind.unscoped.delete_all
      export_models.each do |klass|
        klass.translation_class.unscoped.delete_all
        klass.unscoped.delete_all
      end

      [Event::KindCategory, QualificationKind, Event::Kind].each do |klass|
        (data[klass.table_name] || []).each do |record|
          translations = record.delete("translations") || []
          klass.unscoped.insert_all!([record.slice(*klass.column_names)])
          translations.each do |t|
            klass.translation_class.unscoped.insert_all!(
              [t.slice(*klass.translation_class.column_names)]
            )
          end
        end
      end

      (data[Event::KindQualificationKind.table_name] || []).each do |record|
        Event::KindQualificationKind.unscoped.insert_all!(
          [record.slice(*Event::KindQualificationKind.column_names)]
        )
      end

      tables = export_models.flat_map { |k| [k.table_name, k.translation_class.table_name] }
      tables << Event::KindQualificationKind.table_name
      tables.each { |t| ActiveRecord::Base.connection.reset_pk_sequence!(t) }
    end

    counts = export_models.map { |k| "#{(data[k.table_name] || []).size} #{k.table_name}" }
    counts << "#{(data[Event::KindQualificationKind.table_name] || []).size} " \
      "event_kind_qualification_kinds"
    warn "Imported #{counts.join(", ")}."
  end
end
