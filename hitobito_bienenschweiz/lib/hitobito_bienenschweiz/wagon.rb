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
      #{config.root}/app/decorators
      #{config.root}/app/domain
      #{config.root}/app/jobs
    ]

    config.action_mailer.preview_paths << "#{config.root}/spec/mailers/previews"

    config.to_prepare do # rubocop:disable Metrics/BlockLength
      # extend application classes here
      Group.include Bienenschweiz::Group
      Person.include Bienenschweiz::Person

      # Additional gender option "divers".
      Bienenschweiz::Genders.register!

      Role::Types::Permissions << :layer_contacts
      AbilityDsl::UserContext::GROUP_PERMISSIONS << :layer_contacts
      AbilityDsl::UserContext::LAYER_PERMISSIONS << :layer_contacts
      GroupBasedReadables.same_layer_permissions << :layer_contacts
      PersonLayerWritables.same_layer_permissions << :layer_contacts

      Role::Types::Permissions << :layer_events
      AbilityDsl::UserContext::GROUP_PERMISSIONS << :layer_events
      AbilityDsl::UserContext::LAYER_PERMISSIONS << :layer_events

      NavigationHelper::MAIN << {label: :qcontrols,
       url: :orphan_qcontrols_path,
       icon_name: "list-check",
       if: ->(_) { can?(:manage_orphans, Qcontrol) },
       active_for: %w[orphan_qcontrols]}

      admin_item = NavigationHelper::MAIN.find { |item| item[:label] == :admin }
      admin_item[:active_for] += %w[supervision_type signatures]

      # Keep the "Kurse" main nav section active/expanded while on the
      # feedback report, whose link is added to its left nav via
      # Sheet::FeedbackReport (see app/helpers/sheet/feedback_report.rb).
      courses_item = NavigationHelper::MAIN.find { |item| item[:label] == :courses }
      courses_item[:active_for] += %w[feedback_reports]

      GroupResource.include Bienenschweiz::GroupResource
      PersonResource.include Bienenschweiz::PersonResource
      RoleResource.include Bienenschweiz::RoleResource
      EventResource.include Bienenschweiz::EventResource

      PeopleController.permitted_attrs += [
        :salutation,
        :hive_count,
        :honey_yield,
        :export_to_website,
        :num_ad_boards
      ]

      GroupsController.permitted_attrs += [:code, :member_count]
      Role.used_attributes += [:export_to_website]
      EventsController.permitted_attrs += [:export_to_website]
      Event.used_attributes += [:export_to_website]
      Event.prepend Bienenschweiz::ClearsArrayColumnValidators
      Event::Course.prepend Bienenschweiz::ClearsArrayColumnValidators
      Event::Kind.include Bienenschweiz::Event::Kind
      Event::KindsController.permitted_attrs += [:kas_fee_code, :kas_fixed_fee,
        :kas_instructor_fees]
      Event::ParticipationsController.prepend Bienenschweiz::Event::ParticipationsController
      EventParticipationsHelper.include Bienenschweiz::EventParticipationsHelper

      Event::Question.include Bienenschweiz::Event::Question
      Event::Participation.prepend Bienenschweiz::Event::Participation
      Event::Answer.prepend Bienenschweiz::Event::Answer
      Event::ParticipationDecorator.prepend Bienenschweiz::Event::ParticipationDecorator

      event_question_attrs = EventsController.permitted_attrs.find { |attr| attr.is_a?(Hash) }
      [:application_questions_attributes, :admin_questions_attributes].each do |key|
        event_question_attrs[key] += [:relevance]
      end

      PersonReadables.prepend Bienenschweiz::PersonReadables
      Sheet::Person.prepend Bienenschweiz::Sheet::Person
      Ability.store.register Bienenschweiz::PersonAbility
      Ability.store.register Bienenschweiz::GroupAbility
      Ability.store.register Bienenschweiz::RoleAbility
      Ability.store.register Bienenschweiz::EventAbility
      Ability.store.register Bienenschweiz::EventParticipationAbility
      Ability.store.register Bienenschweiz::EventRoleAbility
      Ability.store.register Bienenschweiz::EventInvitationAbility
      Ability.store.register Bienenschweiz::EventApplicationAbility
      Ability.store.register SignatureAbility
      Ability.store.register DiplomaAbility
      Ability.store.register QcontrolAbility
      Ability.store.register MemoAbility
      Ability.store.register SupervisionAbility
      Ability.store.register SupervisionTypeAbility
      Ability.store.register FeedbackRoundAbility

      TableDisplay.register_column(Person, TableDisplays::PublicColumn, :canton_short)
      Person::FILTER_ATTRS << [:canton_short, :string]

      Event::Kind.include Bienenschweiz::Event::Kind
      Event::KindsController.permitted_attrs += [:abbreviation]
      Event::Course.prepend Bienenschweiz::Event::Course
      Event::KindCategory.include Bienenschweiz::Event::KindCategory
      EventsController.prepend Bienenschweiz::EventsController
      HealthzController.prepend Bienenschweiz::HealthzController
      Event::KindCategoriesController.permitted_attrs += [:layer_group_type]
      Sheet::Event.prepend Bienenschweiz::Sheet::Event

      ActionView::Template.register_template_handler :axlsx,
        Bienenschweiz::AxlsxTemplateHandler.new
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
      # :nocov:
      fixtures = root.join("db", "seeds")
      ENV["NO_ENV"] ? [fixtures] : [fixtures, File.join(fixtures, Rails.env)] # rubocop:disable Rails/EnvironmentVariableAccess -- This is initialization
      # :nocov:
    end
  end
end
