# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

module HitobitoBienenschweiz
  class Wagon < Rails::Engine
    include Wagons::Wagon

    # Set the required application version.
    app_requirement ">= 0"

    # Add a load path for this specific wagon
    config.autoload_paths += %W[
      #{config.root}/app/abilities
      #{config.root}/app/domain
      #{config.root}/app/jobs
    ]

    config.action_mailer.preview_paths << "#{config.root}/spec/mailers/previews"

    config.to_prepare do # rubocop:disable Metrics/BlockLength
      # extend application classes here
      Group.include Bienenschweiz::Group
      Person.include Bienenschweiz::Person

      NavigationHelper::MAIN << {label: :qcontrols,
       url: :orphan_qcontrols_path,
       icon_name: "list-check",
       if: ->(_) { can?(:manage_orphans, Qcontrol) },
       active_for: %w[orphan_qcontrols]}

      admin_item = NavigationHelper::MAIN.find { |item| item[:label] == :admin }
      admin_item[:active_for] += %w[supervision_type]

      GroupResource.include Bienenschweiz::GroupResource

      PeopleController.permitted_attrs += [
        :salutation,
        :hive_count,
        :honey_yield,
        :export_to_website,
        :num_ad_boards
      ]

      GroupsController.permitted_attrs += [:code]
      Role.used_attributes += [:export_to_website]
      EventsController.permitted_attrs += [:export_to_website]
      Event.used_attributes += [:export_to_website]
      Event.default_visible_contact_attributes = %w[name]

      Sheet::Person.prepend Bienenschweiz::Sheet::Person
      Ability.store.register QcontrolAbility
      Ability.store.register SupervisionAbility
      Ability.store.register SupervisionTypeAbility

      TableDisplay.register_column(Person, TableDisplays::PublicColumn, :canton_short)
      Person::FILTER_ATTRS << [:canton_short, :string]

      Event::Course.prepend Bienenschweiz::Event::Course
      EventsController.prepend Bienenschweiz::EventsController
      Sheet::Event.prepend Bienenschweiz::Sheet::Event
    end

    initializer "bienenschweiz.add_settings" do |_app|
      Settings.add_source!(File.join(paths["config"].existent, "settings.yml"))
      Settings.reload!
    end

    initializer "bienenschweiz.add_inflections" do |_app|
      ActiveSupport::Inflector.inflections do |inflect|
        # inflect.irregular "census", "censuses"
      end
    end

    private

    def seed_fixtures
      fixtures = root.join("db", "seeds")
      ENV["NO_ENV"] ? [fixtures] : [fixtures, File.join(fixtures, Rails.env)] # rubocop:disable Rails/EnvironmentVariableAccess -- This is initialization
    end
  end
end
