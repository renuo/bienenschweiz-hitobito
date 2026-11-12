# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

namespace :mv do
  namespace :import do
    GROUP_ID_OFFSET = 10_000
    MEMBER_ID_OFFSET = 10_000
    ROLE_ID_OFFSET = 10_000
    QCONTROL_ID_OFFSET = 10_000
    QUALITY_CONTROL_ANSWER_ID_OFFSET = 10_000
    SUPERVISION_ID_OFFSET = 10_000
    DOCUMENT_ID_OFFSET = 10_000
    MEMO_ID_OFFSET = 10_000

    desc "Import the MV members that have at least one imported role or a running " \
         "magazine subscription in the selectline CSV export (run after groups)"
    task :members, [:abo_path] => :environment do |_, args|
      require "csv"

      abo_path = args[:abo_path]
      abort "Usage: mv:import:members[path/to/export_abo.csv]" if abo_path.blank?
      failure_csv = "invalid_members.csv"

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class KasRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :kas, writing: :kas}
      end

      class Member < MvRecord
        has_one :login

        def kas_user
          @@users ||= User.all.to_h { |u| [u.member_id, u] }
          @kas_user ||= @@users[id]
        end
      end

      class Login < MvRecord
        belongs_to :member
      end

      class User < KasRecord
      end

      class MvMember < MvRecord
        self.table_name = "members"
      end

      class MvRole < MvRecord
        self.table_name = "roles"
      end

      class InternStructure < MvRecord
        enum :structure_type, {verein: 1, verband: 2, sektion: 3}
      end

      class Membership < MvRecord
        belongs_to :role, class_name: "MvRole"
        belongs_to :intern_structure
      end

      # The old system contains a lot of people that should not be taken over. Only members with
      # a membership that is imported as role (see the roles task) or with a running magazine
      # subscription are imported. All other data of excluded members is skipped by the later tasks.
      role_member_ids = Membership.includes(:role, :intern_structure).find_each.filter_map do |membership|
        membership.member_id if importable_role(membership)
      end.to_set
      subscriber_member_ids = subscription_customer_numbers(abo_path).filter_map do |number|
        ids = selectline_member_ids[number]
        ids.first if ids&.one?
      end.to_set
      puts "Members with imported roles: #{role_member_ids.count}, " \
           "with running subscriptions but without roles: #{(subscriber_member_ids - role_member_ids).count}"

      # MV tagged ad boards (Werbetafeln) with one membership per board. They are imported as
      # the number of active memberships, the 2015-2017 boards are counted as legacy boards.
      ad_board_roles = {
        num_ad_boards: %w[Siegelimker_Werbetafel_2020],
        num_ad_boards_legacy: %w[Siegelimker_Werbetafel_2015 Siegelimker_Werbetafel_2016
          Siegelimker_Werbetafel_2017]
      }
      today = Date.current
      ad_board_counts = ad_board_roles.transform_values do |role_names|
        Membership.joins(:role)
          .where(roles: {name: role_names})
          .where("memberships.valid_from IS NULL OR memberships.valid_from <= ?", today)
          .where("memberships.valid_until IS NULL OR memberships.valid_until >= ?", today)
          .group(:member_id)
          .count
      end
      puts "Members with ad boards: " +
        ad_board_counts.map { |attr, counts| "#{attr}: #{counts.count}" }.join(", ")

      total_count = 0
      success_count = 0
      email_duplicate_count = 0
      import_without_validations = 0
      failed_members = {}

      # additional emails get the next free category in this order, since each category may only be
      # used once per person. invoices is left out on purpose so imported emails don't receive invoices.
      additional_email_categories = %w[private work other].map do |key|
        ContactAccountCategory.for(AdditionalEmail, Person).find_by!(key:)
      end

      def try_add_phone(person, number, type)
        return if number.blank?

        sanitized_number = Phonelib.parse(number)
        if sanitized_number.valid?
          number = sanitized_number.international
          person.phone_numbers.where(number:).first_or_initialize do |phone|
            phone.number = number
            phone.category = ContactAccountCategory.for(PhoneNumber, Person).find_by!(key: type)
          end
        else
          puts "Ignoring invalid #{type} number: #{number}"
        end
      end

      scope = Member.all.includes(:login)
      # scope = scope.limit(10)
      scope = scope.where(robinson: false)
      scope = scope.where(id: (role_member_ids | subscriber_member_ids).to_a)
      puts "Excluding #{Member.where(robinson: false).count - scope.count} members without roles or subscriptions"
      scope.find_each do |member|
        total_count += 1
        new_id = member.id + ::MEMBER_ID_OFFSET # offset to not conflict with admin or test data
        person = Person.where(id: new_id).first_or_initialize do |person|
          person.id = new_id
        end
        begin
          person.first_name = member.firstname
          person.last_name = member.lastname
          person.address_care_of = [member.affix_1, member.affix_2,
            member.affix_3].map(&:presence).compact.join(", ")
          person.street = member.street
          person.housenumber = member.house_no
          person.postbox = [member.pobox, member.pobox_zip,
            member.pobox_zip_ex].map(&:presence).compact.join(", ")
          person.salutation = member.salutation
          person.hive_count = member.hive_count
          person.honey_yield = member.honey_yield
          person.zip_code = member.zip
          person.town = member.location
          person.created_at = member.created_at
          person.updated_at = member.updated_at
          person.email = (member.login || member.kas_user)&.email
          member.email_contacts.each do |email|
            person.email ||= email unless email == 'honig@bienenschweiz.ch'
            next if email == person.email || person.additional_emails.any? { |e| e.email == email }

            used_category_ids = person.additional_emails.map(&:category_id)
            category = additional_email_categories.find { |c| used_category_ids.exclude?(c.id) }
            if category
              person.additional_emails.build(email:, category:)
            else
              puts "Skipping additional email #{email} of member #{member.id}: no free email category left"
            end
          end
          person.birthday = member.birthdate
          person.export_to_website = member.typo3_export
          ad_board_counts.each { |attr, counts| person[attr] = counts[member.id] }
          if key = member.lang_key
            person.language = {D: "de", E: "en", F: "fr", I: "it"}.fetch(key&.to_sym)
          end
          try_add_phone(person, member.phone1, :landline)
          try_add_phone(person, member.phone2, :other)
          try_add_phone(person, member.mobile, :mobile)
          try_add_phone(person, member.office_phone, :work)

          unless member.country_key.blank?
            if (iso_country = ISO3166::Country[member.country_key])
              person.country = iso_country.translations["de"]
            else
              raise "Unknown country_key #{member.country_key}"
            end
          end

          person.validate
          if person.errors.count == 1 && person.errors[:zip_code].present? && person.country != "CH"
            puts "Importing member #{member.id} without validations"
            person.save!(validate: false)
            import_without_validations += 1
          else
            person.save!
          end
          success_count += 1
        rescue StandardError => e
          puts "--- Error importing member #{member.id}: #{e.message}"
          # puts e.backtrace
          p member
          puts "Login: #{member.login.inspect}"
          puts "User: #{member.kas_user.inspect}"
          p person
          if person.errors[:email].present?
            p person.errors[:email]
            email_duplicate_count += 1
          end
          puts "\n"
          failed_members[member] = [e.message,person]
        end
      end
      CSV.open(failure_csv, "w",
        write_headers: true,
        headers: ["id", "selectline_number", "email", "error"]) do |csv|
        failed_members.each do |m, (error,person)|
          csv << [m.id, m.selectline_customer_number, person&.email, error]
        end
      end
      puts "Imported #{success_count}/#{total_count} members (email duplicate: #{email_duplicate_count}, imported without zip validation: #{import_without_validations})"
    end
    task groups: :environment do
      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class InternStructure < MvRecord
        enum :structure_type, {verein: 1, verband: 2, sektion: 3}
      end

      root_group = Group::Dachverband.first
      InternStructure.where(structure_type: InternStructure.structure_types[:verband]).find_each do |verband|
        group = Group::Kantonalverband.where(name: verband.name).first_or_initialize do |group|
          group.id = verband.id + GROUP_ID_OFFSET
        end
        group.parent = root_group
        group.code = verband.code
        group.created_at = verband.created_at
        group.updated_at = verband.updated_at
        group.save!
        try_add_website(group, verband)
      end

      InternStructure.where(structure_type: InternStructure.structure_types[:sektion]).find_each do |sektion|
        group = Group::Sektion.where(name: sektion.name).first_or_initialize do |group|
          group.id = sektion.id + GROUP_ID_OFFSET
        end
        group.parent = Group::Kantonalverband.find(sektion.parent_id + GROUP_ID_OFFSET)
        group.code = sektion.code
        group.member_count = sektion.member_count
        group.created_at = sektion.created_at
        group.updated_at = sektion.created_at
        begin
          group.save!
        rescue StandardError => e
          puts "Error importing sektion #{sektion.id}: #{e.message}"
          p sektion
        end
        try_add_website(group, sektion)
      end
    end

    def try_add_website(group, intern_structure)
      @category ||= ContactAccountCategory.for(SocialAccount, Group).find_by!(key: :website)
      if intern_structure.url.present?
        group.social_accounts.where(category: @category, name: intern_structure.url).first_or_create!
      end
    end

    def find_role(membership)
      ad_roles = ["SI_We", "SI_WE", "SI WE", "SI_WE 2020"] # the different spellings are for different years ...
      if ad_roles.include?(membership.role.name_t)
        # imported as num_ad_boards(_legacy) by the members task
        return -1
      end
      # this one isn't included in the mapping table at all. shows up on verein and sektion
      return nil if membership.role.name_t == "Ansprechsperson Asiatische Hornisse"
      case membership.intern_structure.structure_type
      when "verband"
        case membership.role.name_t
        when "P", "KP"
          Group::KantonalverbandVorstand::Praesident
        when "K"
          Group::KantonalverbandVorstand::Kassier
        when "B", "B-PROV", "H", "Z", "Z-PROV", "SI", "SI-PROV"
          # only exists on Sektion.
        when "INSP", "B-INFO", "SU"
          # only exists on Verein
        when "BO"
          Group::KantonalverbandVorstand::Bildung
        when "ZO"
          Group::KantonalverbandVorstand::Zucht
        when "HO"
          Group::KantonalverbandVorstand::Produkte
        when "HO-PROV"
          # no longer a thing
        when "H-PROV"
          # only exists on Sektion
        when "INS", "KP-prov"
          # marked as archived and ignored
          -1
        when /IB_(\d+|F)/, "Kaderkurs 0"
          # needs to be mapped to courses later
          -1
        when "FA", "FA_F", "IK", "BS_EK", /BS_VK_B\d/
          # needs to be mapped to qualifications later
          -1
        when "EV"
          # only exists on Sektion now
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for verband"
        end
      when "sektion"
        case membership.role.name_t
        when "B"
          Group::Kader::FachpersonBildung
        when "B-PROV"
          # no longer a thing
        when "Z"
          Group::Kader::FachpersonZuchtVermehrung
        when "Z-PROV"
          # no longer a thing
        when "P"
          Group::SektionVorstand::Praesident
        when "K"
          Group::SektionVorstand::Kassier
        when "H"
          Group::Kader::FachpersonProdukte
        when "H-PROV"
          # no longer a thing
        when "SI"
          Group::Siegelimker::Siegelimker
        when "SI-PROV"
          # no longer a thing
        when "EV"
          Group::SektionAdministrator::ErfassungVeranstaltungen
        when "HAN", "INS", "BEA", "SM"
          # marked as archived and ignored
          -1
        when /IB_\d+/, "Kaderkurs 0"
          # needs to be mapped to courses later
          -1
        when "INSP"
          # only exists on Verein
        when "KP"
          # only exists on Verband
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for sektion"
        end
      when "verein"
        case membership.role.name_t
        when "sekretariat", "HAN", "Mitglied Kontrollstelle", "INS", "HK"
          # marked as archived and ignored
        when "A"
          Group::Dachverband::AdministratorBienenSchweiz
        when "SU"
          Group::ThemenbezogeneKontakte::Supervisor
        when "EP"
          Group::Mitglieder::Ehrenpraesident
        when "EM"
          Group::Mitglieder::Ehrenmitglied
        when "ZV"
          Group::Zentralvorstand::Beisitzer
        when "Mitglied VDRB" # Probably?
          Group::Mitglieder::AnderesMitglied
        when "INSP"
          # currently not mapped
        when "EV", "SI"
          # only exists on Sektion now
        when "H-PROV"
          # only exists on Verband
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for verein"
        end
      else
        raise "Unsupported structure type #{membership.intern_structure.structure_type}"
      end
    end

    # Ended admin memberships are not imported, they are no reason to import the member either.
    def ended_admin_role?(role_type, membership)
      role_type == Group::Dachverband::AdministratorBienenSchweiz && membership.valid_until&.past?
    end

    def role_group(membership, role_type)
      @role_groups ||= {}
      key = [membership.intern_structure_id, role_type]
      return @role_groups[key] if @role_groups.key?(key)

      group_class = role_type.model_name.to_s.deconstantize.constantize
      group = if membership.intern_structure.verein?
        Group.root
      else
        Group.find_by(id: membership.intern_structure_id + GROUP_ID_OFFSET)
      end
      @role_groups[key] = group.is_a?(group_class) ? group : group&.children&.find_by(type: group_class.sti_name)
    end

    # The role type and group a membership is imported as, nil if it is not imported.
    def importable_role(membership)
      role_type = find_role(membership)
      return unless role_type.is_a?(Class) && !ended_admin_role?(role_type, membership)

      group = role_group(membership, role_type)
      [role_type, group] if group
    rescue StandardError
      nil # unknown mappings are reported by the roles task
    end

    # selectline customer numbers of the recipients and gifters of running magazine subscriptions
    def subscription_customer_numbers(path)
      numbers = Set.new
      CSV.foreach(path, headers: true, col_sep: ";", encoding: "bom|utf-8") do |row|
        next if row["Kündigungsdatum"].to_s.strip.present?

        numbers << row["adressnummer"].to_s.strip << row["geschenkabo von Kunde"].to_s.strip
      end
      numbers.delete("")
      numbers
    end

    # Whether the person of the MV member was imported, the members task only imports some of them.
    def imported_member?(member_id)
      @imported_person_ids ||= Person.pluck(:id).to_set
      @imported_person_ids.include?(member_id + MEMBER_ID_OFFSET)
    end

    task roles: :environment do
      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class MvRole < MvRecord
        self.table_name = "roles"
      end

      class InternStructure < MvRecord
        enum :structure_type, {verein: 1, verband: 2, sektion: 3}
      end

      class Membership < MvRecord
        belongs_to :role, class_name: "MvRole"
        belongs_to :intern_structure
      end

      admin = Person.find(1)
      scope = Membership
      total = scope.count
      mapped_count = 0
      unknown_mappings = []
      scope.includes(:role, :intern_structure).find_each do |membership|
        role_type = find_role(membership)
        if role_type.nil?
          puts "Unknown mapping for #{membership.id} with role #{membership.role.name} (#{membership.role.name_t}) on structure type #{membership.intern_structure.structure_type}"
          unknown_mappings |= [[membership.role, membership.intern_structure.structure_type]]
          next
        end
        if role_type == -1
          # puts "Skipping #{membership.id} with role #{membership.role.name} (#{membership.role.name_t}) on structure type #{membership.intern_structure.structure_type}"
          next
        end
        next if ended_admin_role?(role_type, membership)

        group = role_group(membership, role_type)
        raise "No group for #{role_type} of membership #{membership.id}" unless group

        person = Person.find(membership.member_id + ::MEMBER_ID_OFFSET)

        # TODO: do we need/want this?
        # PeopleManager.where(managed: person, manager: admin).first_or_create!

        role_id = membership.id + ROLE_ID_OFFSET
        role = person.roles.with_inactive.where(id: role_id).first_or_initialize
        role.update(type: role_type.sti_name,
          group: group,
          start_on: membership.valid_from,
          end_on: membership.valid_until,
          created_at: membership.created_at,
          updated_at: membership.updated_at)
        role.save!
        mapped_count += 1
      rescue StandardError => e
        puts e.message
      end
      puts "Mapped #{mapped_count}/#{total} roles"
      puts "#{unknown_mappings.count} unknown mappings:"
      unknown_mappings.each do |role, structure_type|
        puts "#{role.name} (#{role.name_t}) on #{structure_type}"
      end
    end

    desc "Create qualifications from imported Fachperson roles and Siegelimker qcontrols " \
         "(run after roles and quality_controls)"
    task qualifications: :environment do
      find_kind = lambda do |label|
        QualificationKind.joins(:translations)
          .find_by!(qualification_kind_translations: {label: "Qualifikation #{label}"})
      end

      upsert = lambda do |person_id, kind, start_at|
        qualification = Qualification.find_or_initialize_by(person_id:, qualification_kind: kind)
        qualification.update!(start_at:, qualified_at: start_at, origin: "MV Import")
      end

      # Fachpersonen keep their qualification forever, even if the role has ended.
      # The start date is the start of their oldest role of that kind.
      {
        Group::Kader::FachpersonBildung => "Fachperson Bildung",
        Group::Kader::FachpersonProdukte => "Fachperson Produkte",
        Group::Kader::FachpersonZuchtVermehrung => "Fachperson Zucht"
      }.each do |role_type, label|
        kind = find_kind.call(label)
        count = 0
        Role.with_inactive.where(type: role_type.sti_name)
          .group(:person_id)
          .pluck(:person_id, Arel.sql("MIN(COALESCE(start_on, created_at::date))"))
          .each do |person_id, start_at|
            upsert.call(person_id, kind, start_at)
            count += 1
          rescue StandardError => e
            puts "Error creating #{label} qualification for person #{person_id}: #{e.message}"
          end
        puts "Created #{count} #{label} qualifications"
      end

      # Siegelimker are qualified by their last (partially) passed qcontrol. The finish date
      # is derived from the validity of the qualification kind.
      kind = find_kind.call("Siegelimker/in")
      count = 0
      passed = Qcontrol.where(control_state: %w[passed partially_passed]).where.not(person_id: nil)
      missing = passed.where.not(person_id: Person.select(:id)).distinct.count(:person_id)
      puts "Skipping #{missing} not imported people with passed qcontrols" if missing.positive?
      passed.where(person_id: Person.select(:id))
        .group(:person_id)
        .maximum(:control_date)
        .each do |person_id, control_date|
          upsert.call(person_id, kind, control_date)
          count += 1
        rescue StandardError => e
          puts "Error creating Siegelimker qualification for person #{person_id}: #{e.message}"
        end
      puts "Created #{count} Siegelimker qualifications"
    end

    task :quality_controls, [:redo_docs] => :environment do |t, args|
      require "carrierwave"

      class AssetUploader < CarrierWave::Uploader::Base
        def store_dir
          "uploads/#{model.class.to_s.pluralize.underscore.gsub("mv_",
            "")}/#{model.member_id}/#{model.id}"
        end

        def remove!
          nil
        end
      end

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end
      require "carrierwave/orm/activerecord"

      class KasRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :kas, writing: :kas}
      end

      # Mv prefix to not conflict with the identically named wagon models
      class MvQualityControlSection < MvRecord
        self.table_name = "quality_control_sections"
      end

      class MvQualityControlQuestion < MvRecord
        self.table_name = "quality_control_questions"
      end

      class MvQcontrol < MvRecord
        self.table_name = "qcontrols"
        mount_uploader :document, AssetUploader
      end

      class MvQualityControlAnswer < MvRecord
        self.table_name = "quality_control_answers"
      end

      class User < KasRecord
      end

      # upsert_all skips callbacks (qcontrols send notification mails on create)
      # and validations, imports the data as-is and is idempotent.
      import = lambda do |model, rows|
        rows.each_slice(1000) { |slice| model.upsert_all(slice) }
        puts "Imported #{rows.count} #{model.model_name.human(count: rows.count)}"
      end

      # sections and questions are reference data and keep their original ids
      import.call(QualityControlSection, MvQualityControlSection.find_each.map(&:attributes))
      import.call(QualityControlQuestion, MvQualityControlQuestion.find_each.map(&:attributes))

      # inspector_id references a kas user in MV, but a person in hitobito
      inspector_member_ids = User.where.not(member_id: nil).pluck(:id, :member_id).to_h

      imported_qcontrol_ids = Set.new
      skipped = 0
      MvQcontrol.find_each do |mv_qcontrol|
        if mv_qcontrol.member_id && !imported_member?(mv_qcontrol.member_id)
          skipped += 1
          next
        end
        imported_qcontrol_ids << mv_qcontrol.id
        inspector_member_id = inspector_member_ids[mv_qcontrol.inspector_id]
        qcontrol = Qcontrol.where(id: mv_qcontrol.id + QCONTROL_ID_OFFSET).first_or_initialize
        qcontrol.update(mv_qcontrol.attributes.except("id", "member_id", "intern_structure_id", "document", "content_type", "file_size").merge(
          "person_id" => mv_qcontrol.member_id && mv_qcontrol.member_id + MEMBER_ID_OFFSET,
          "author_id" => mv_qcontrol.author_id && mv_qcontrol.author_id + MEMBER_ID_OFFSET,
          "group_id" => mv_qcontrol.intern_structure_id + GROUP_ID_OFFSET,
          "inspector_id" => inspector_member_id && inspector_member_id + MEMBER_ID_OFFSET
        ))
        if (args[:redo_docs] == "true" || !qcontrol.document.attached?) && mv_qcontrol.document.present?
          Tempfile.open("qcontrol-#{mv_qcontrol.id}") do |f|
            f.binmode
            f.write(mv_qcontrol.document.file.read)
            f.rewind
            qcontrol.document.attach(
              io: f,
              filename: mv_qcontrol.document.file.filename,
              content_type: mv_qcontrol.content_type
            )
            qcontrol.save(validate: false)
            f.close
          rescue StandardError => e
            puts "Error attaching document for qcontrol #{qcontrol.id}: #{e.message}"
          end
        end
      end

      puts "Skipped #{skipped} qcontrols of not imported members"

      answer_rows = MvQualityControlAnswer.find_each.filter_map do |answer|
        next unless imported_qcontrol_ids.include?(answer.qcontrol_id)

        answer.attributes.merge(
          "id" => answer.id + QUALITY_CONTROL_ANSWER_ID_OFFSET,
          "qcontrol_id" => answer.qcontrol_id + QCONTROL_ID_OFFSET
        )
      end
      import.call(QualityControlAnswer, answer_rows)

      # report references to people/groups that are missing (e.g. failed member imports)
      missing = {
        people: Qcontrol.where.not(person_id: nil).where.not(person_id: Person.select(:id)).count,
        authors: Qcontrol.where.not(author_id: nil).where.not(author_id: Person.select(:id)).count,
        inspectors: Qcontrol.where.not(inspector_id: nil).where.not(inspector_id: Person.select(:id)).count,
        groups: Qcontrol.where.not(group_id: Group.select(:id)).count,
        kas_inspectors: MvQcontrol.where.not(inspector_id: nil).where.not(inspector_id: inspector_member_ids.keys).count
      }
      puts "Qcontrols with dangling references: #{missing.map { |k, v| "#{k}: #{v}" }.join(", ")}"
    end

    def find_or_create_supervision_type(mv_course_type)
      name = case mv_course_type
      when "base_course"
        "Grundkurs"
      when "lecture"
        "Gruppenberatungen und Vorträge"
      when "zuchtkurs"
        "Zuchtkurs"
      when "test"
        "Betriebsprüfung"
      end
      return nil unless name

      SupervisionType.find_or_create_by!(name:)
    end

    task :supervisions, [:redo_docs] => :environment do |_t, args|
      require "carrierwave"

      class AssetUploader < CarrierWave::Uploader::Base
        def store_dir
          "uploads/#{model.class.to_s.pluralize.underscore.gsub("mv_",
            "")}/#{model.member_id}/#{model.id}"
        end

        def remove!
          nil
        end
      end

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end
      require "carrierwave/orm/activerecord"

      class MvSupervision < MvRecord
        self.table_name = "supervisions"
        mount_uploader :document, AssetUploader
        enum :course_type, { base_course: 'base_course', lecture: 'lecture', zuchtkurs: 'zuchtkurs', test: 'test' }
      end

      count = 0
      skipped = 0
      MvSupervision.find_each do |mv_supervision|
        if mv_supervision.member_id && !imported_member?(mv_supervision.member_id)
          skipped += 1
          next
        end
        supervision = Supervision.where(id: mv_supervision.id + SUPERVISION_ID_OFFSET).first_or_initialize
        supervision.assign_attributes(
          mv_supervision.attributes.except("id", "member_id", "document", "content_type", "file_size", "course_type").merge(
            "person_id" => mv_supervision.member_id && mv_supervision.member_id + MEMBER_ID_OFFSET,
            "author_id" => mv_supervision.author_id && mv_supervision.author_id + MEMBER_ID_OFFSET,
            "supervisor_id" => mv_supervision.supervisor_id && mv_supervision.supervisor_id + MEMBER_ID_OFFSET,
            "supervision_type" => find_or_create_supervision_type(mv_supervision.course_type)
          )
        )
        supervision.save(validate: false)
        if (args[:redo_docs] == "true" || !supervision.document.attached?) && mv_supervision.document.present?
          Tempfile.open("supervision-#{mv_supervision.id}") do |f|
            f.binmode
            f.write(mv_supervision.document.file.read)
            f.rewind
            supervision.document.attach(
              io: f,
              filename: mv_supervision.document.file.filename
            )
            supervision.save(validate: false)
          rescue StandardError => e
            puts "Error attaching document for supervision #{supervision.id}: #{e.message}"
          end
        end
        count += 1
      end
      puts "Imported #{count} supervisions, skipped #{skipped} of not imported members"

      missing = {
        people: Supervision.where.not(person_id: Person.select(:id)).count,
        authors: Supervision.where.not(author_id: nil).where.not(author_id: Person.select(:id)).count,
        supervisors: Supervision.where.not(supervisor_id: nil).where.not(supervisor_id: Person.select(:id)).count,
        supervision_types: Supervision.where.not(supervision_type_id: nil).where.not(supervision_type_id: SupervisionType.select(:id)).count
      }
      puts "Supervisions with dangling references: #{missing.map { |k, v|
        "#{k}: #{v}"
      }.join(", ")}"
    end

    task :documents, [:redo_docs] => :environment do |_t, args|
      require "carrierwave"

      class AssetUploader < CarrierWave::Uploader::Base
        def store_dir
          "uploads/#{model.class.to_s.pluralize.underscore.gsub("mv_",
            "")}/#{model.member_id}/#{model.id}"
        end

        def remove!
          nil
        end
      end

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end
      require "carrierwave/orm/activerecord"

      class MvDocument < MvRecord
        self.table_name = "documents"
        mount_uploader :document, AssetUploader
      end

      count = 0
      skipped = 0
      MvDocument.find_each do |mv_document|
        unless imported_member?(mv_document.member_id)
          skipped += 1
          next
        end
        doc = PersonalDocument.where(id: mv_document.id + DOCUMENT_ID_OFFSET).first_or_initialize
        doc.assign_attributes(
          "person_id" => mv_document.member_id + MEMBER_ID_OFFSET,
          "author_id" => mv_document.author_id + MEMBER_ID_OFFSET,
          "description" => mv_document.title,
          "created_at" => mv_document.created_at,
          "updated_at" => mv_document.updated_at
        )
        doc.save(validate: false)
        if (args[:redo_docs] == "true" || !doc.file.attached?) && mv_document.document.present?
          Tempfile.open("document-#{mv_document.id}") do |f|
            f.binmode
            f.write(mv_document.document.file.read)
            f.rewind
            doc.file.attach(
              io: f,
              filename: mv_document.document.file.filename,
              content_type: mv_document.content_type
            )
            doc.save(validate: false)
          rescue StandardError => e
            puts "Error attaching file for document #{doc.id}: #{e.message}"
          end
        end
        count += 1
      rescue StandardError => e
        puts "Error importing document #{mv_document.id}: #{e.message}"
      end
      puts "Imported #{count} documents, skipped #{skipped} of not imported members"

      missing = {
        people: PersonalDocument.where.not(person_id: Person.select(:id)).count,
        authors: PersonalDocument.where.not(author_id: Person.select(:id)).count
      }
      puts "Documents with dangling references: #{missing.map { |k, v| "#{k}: #{v}" }.join(", ")}"
    end

    task memos: :environment do
      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class MvMemo < MvRecord
        self.table_name = "memos"
      end

      count = 0
      skipped = 0
      MvMemo.find_each do |mv_memo|
        unless imported_member?(mv_memo.member_id)
          skipped += 1
          next
        end
        memo = Memo.where(id: mv_memo.id + MEMO_ID_OFFSET).first_or_initialize
        memo.assign_attributes(
          mv_memo.attributes.except("id", "member_id", "text", "show_on_personnel_file").merge(
            "body" => mv_memo.text,
            "person_id" => mv_memo.member_id + MEMBER_ID_OFFSET,
            "author_id" => mv_memo.author_id && mv_memo.author_id + MEMBER_ID_OFFSET
          )
        )
        memo.save(validate: false)
        count += 1
      rescue StandardError => e
        puts "Error importing memo #{mv_memo.id}: #{e.message}"
      end
      puts "Imported #{count} memos, skipped #{skipped} of not imported members"

      missing = {
        people: Memo.where.not(person_id: Person.select(:id)).count,
        authors: Memo.where.not(author_id: nil).where.not(author_id: Person.select(:id)).count
      }
      puts "Memos with dangling references: #{missing.map { |k, v| "#{k}: #{v}" }.join(", ")}"
    end

    task fees: :environment do
      class KasRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :kas, writing: :kas}
      end

      class KasFeeType < KasRecord
        self.table_name = "fee_types"
      end

      class KasFee < KasRecord
        self.table_name = "fees"
        belongs_to :fee_type, class_name: "KasFeeType"
        belongs_to :user, class_name: "KasUser"
        enum :state, %i[pending accepted rejected payed deleted].freeze
      end

      class KasUser < KasRecord
        self.table_name = "users"
      end

      kas_fee_types = {
        "Grundkurs 2 (Pauschale)" => "Basiskurs Imkern",
        "Kaderkurs I (Betriebsberater) - Kursleiter" => "Fachperson Bildung",
        "Kaderkurs I (Betriebsberater) - Teilnehmer" => "Fachperson Bildung",
        "Kaderkurs II (Betriebsprüfer) - Kursleiter" => "Fachperson Produkte",
        "Kaderkurs II (Betriebsprüfer) - Teilnehmer" => "Fachperson Produkte",
        "Kaderkurs III (Zuchtberater) - Kursleiter" => "Fachperson Zucht",
        "Kaderkurs III (Zuchtberater) - Teilnehmer" => "Fachperson Zucht",
        "Kaderweiterbildung I (Betriebsberater) - Kursleiter" => "Kaderweiterbildung Bildung",
        "Kaderweiterbildung I (Betriebsberater) - Teilnehmer" => "Kaderweiterbildung Bildung",
        "Kaderweiterbildung II (Betriebsprüfer) - Kursleiter" => "Kaderweiterbildung Produkte",
        "Kaderweiterbildung II (Betriebsprüfer/-in) - Teilnehmer/-in" => "Kaderweiterbildung Produkte",
        "Kaderweiterbildung III (Zuchtberater) - Kursleiter" => "Kaderweiterbildung Zucht",
        "Kaderweiterbildung III (Zuchtberater) - Teilnehmer" => "Kaderweiterbildung Zucht"
      }
      kas_fees = KasFee.joins(:fee_type).where(fee_type: { title: kas_fee_types.keys }).payed
      event_kinds = Event::Kind.pluck(:label, :id).to_h
      courses = {}
      import_count = 0
      merge_count = 0
      skipped = 0

      kas_fees.includes(:fee_type, :user).find_each do |kas_fee|
        member_id = kas_fee.user&.member_id
        unless member_id && imported_member?(member_id)
          skipped += 1
          next
        end

        kind = kas_fee_types[kas_fee.fee_type.title]
        kind_id = event_kinds[kind]
        group_id = kas_fee.intern_structure_id + GROUP_ID_OFFSET
        date = Event::Date.new(start_at: kas_fee.occurred_on)
        key = [kind_id, group_id, kas_fee.occurred_on]
        merge_count += 1 if courses.key?(key)

        course = courses[key] ||= Event::Course.create!(
          name: "#{kas_fee.fee_type.title} #{kas_fee.occurred_on.strftime("%d.%m.%Y")}",
          location: kas_fee.place, cost: kas_fee.total_amount,
          kind_id: kind_id, group_ids: [group_id], dates: [date],
          globally_visible: false,
          export_to_website: false
        )
        participation = course.participations.create!(
          participant_id: member_id + MEMBER_ID_OFFSET,
          participant_type: Person.sti_name, active: true
        )
        role = kind == "Basiskurs Imkern" ? Event::Role::Leader : Event::Course::Role::Participant
        participation.roles.create!(type: role.sti_name)
        import_count += 1
      rescue StandardError => e
        puts "Error importing fee #{kas_fee.id}: #{e.message}"
      end

      puts "Imported #{import_count} and grouped #{merge_count} courses, " \
           "skipped #{skipped} fees of not imported members"
    end

    # MV member ids by selectline customer number, which is only available in MV.
    # Requires the MvMember class to be defined by the calling task.
    def selectline_member_ids
      return @selectline_member_ids if @selectline_member_ids

      @selectline_member_ids = MvMember.where.not(selectline_customer_number: [nil, ""])
        .pluck(:selectline_customer_number, :id)
        .group_by { |number, _| number.to_s.strip }
        .transform_values { |pairs| pairs.map(&:last) }
      @selectline_member_ids.select { |_, ids| ids.many? }.each do |number, ids|
        puts "Selectline customer number #{number} is used by multiple members: #{ids.join(", ")}"
      end
      @selectline_member_ids
    end

    desc "Import running Bienenzeitung subscriptions from the selectline CSV export " \
         "(invalid_members_path defaults to invalid_members.csv of the members import)"
    task :magazine_subscriptions, [:path, :invalid_members_path] => :environment do |_, args|
      require "csv"

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class MvMember < MvRecord
        self.table_name = "members"
      end

      failure_csv = "invalid_magazine_subscriptions.csv"
      subscription_types = {
        "abo-biez" => "abo",
        "abo-biez-EURO" => "abo_eur",
        # CHF priced subscriptions delivered to the EU, the old system had no own type for them
        "abo-biez-CHF-EU" => "abo"
      }
      bienen_zeitung = Group::BienenZeitung.first!
      subscriber_role = Group::BienenZeitung::Abonnent.sti_name
      text = ->(value) { value.to_s.strip.presence }

      # errors of the members import by MV member id, to explain why a member is missing
      invalid_members_path = args[:invalid_members_path] || "invalid_members.csv"
      member_errors = if File.exist?(invalid_members_path)
        CSV.foreach(invalid_members_path, headers: true).to_h { |row| [row["id"].to_i, row["error"]] }
      else
        puts "#{invalid_members_path} not found, missing members are reported without reason"
        {}
      end
      missing_member_reason = lambda do |member_id|
        if (error = member_errors[member_id])
          "failed member import: #{error.chomp}"
        elsif MvMember.where(id: member_id).pick(:robinson)
          "excluded on purpose: robinson"
        else
          "unknown reason"
        end
      end

      # needs to be reset if the roles import ran but the mv:import:reset_id_sequences hasn't yet
      ActiveRecord::Base.connection.reset_pk_sequence!("roles")

      find_person = lambda do |number|
        ids = selectline_member_ids[number]
        raise "Unknown selectline customer number #{number}" if ids.blank?
        raise "Ambiguous selectline customer number #{number}" if ids.many?

        Person.find_by(id: ids.first + MEMBER_ID_OFFSET) ||
          raise("Member #{ids.first} (selectline customer number #{number}) was not imported " \
                "(#{missing_member_reason.call(ids.first)})")
      end

      stats = Hash.new(0)
      failed_rows = []
      seen_rows = Set.new
      headers = nil
      CSV.foreach(args[:path], headers: true, col_sep: ';', encoding: "bom|utf-8") do |row|
        headers ||= row.headers
        stats[:total] += 1
        # we only import running subscriptions
        if text.call(row["Kündigungsdatum"])
          stats[:cancelled] += 1
          next
        end
        # the export contains some rows multiple times
        unless seen_rows.add?(row.fields)
          stats[:duplicate] += 1
          next
        end

        number = text.call(row["adressnummer"])
        if (reason = text.call(row["Kündigungsgrund"]))
          puts "Ignoring cancellation reason #{reason} of running subscription of #{number}"
        end

        billing_date = text.call(row["nächster Verrechnungstermin"])
        raise "Missing next billing date" unless billing_date

        gifter_number = text.call(row["geschenkabo von Kunde"])
        subscription_type = if gifter_number
          "geschenk_abo"
        elsif text.call(row["GR Abo"])
          "gratis_abo"
        else
          subscription_types.fetch(text.call(row["artikelnummer"])) do |article|
            raise "Unknown article number #{article}"
          end
        end

        person = find_person.call(number)
        subscription = person.magazine_subscriptions.where(
          subscription_type:,
          start_date: Date.strptime(billing_date, "%d.%m.%Y").prev_year,
          gifter: gifter_number && find_person.call(gifter_number)
        ).first_or_initialize
        subscription.amount = Integer(row["Anzahl"])

        MagazineSubscription.transaction do
          unless person.roles.exists?(type: subscriber_role)
            person.roles.create!(type: subscriber_role, group: bienen_zeitung)
          end
          subscription.save!
        end
        stats[:imported] += 1
      rescue => e
        stats[:failed] += 1
        puts "Row #{stats[:total]} (#{row["adressnummer"]}): #{e.message}"
        failed_rows << row.fields + [e.message]
      end

      CSV.open(failure_csv, "w", write_headers: true, headers: headers.to_a + ["error"]) do |csv|
        failed_rows.each { |fields| csv << fields }
      end
      puts stats.map { |key, count| "#{key}: #{count}" }.join(", ")
      puts "Failed rows written to #{failure_csv}" if failed_rows.any?
      puts headers.inspect
    end

    desc "Import website profiles of Siegelimker from the website CSV export " \
         "(set SKIP_IMAGES=1 to skip downloading background images)"
    task :siegelimker_profiles, [:path] => :environment do |_, args|
      require "csv"
      require "open-uri"

      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end

      class MvMember < MvRecord
        self.table_name = "members"
      end

      availabilities = {
        "nicht im Angebot" => "not_offered",
        "derzeit erhältlich" => "available",
        "derzeit leider nicht erhältlich" => "unavailable"
      }
      products = {
        honey: "honig_mit_goldenem_qualitaetssiegel",
        propolis: "propolis",
        pollen: "pollen",
        queens: "bienenkoniginnen",
        wax: "wachs"
      }
      prefixes = ["", "2_", "3_", "4_", "5_"]

      boolean = ->(value) { value.to_s.strip == "Ja" }
      text = ->(value) { value.to_s.strip.presence }

      find_person = lambda do |row|
        # ext_id is the selectline customer number of the member
        ext_id = text.call(row["ext_id"])
        email = text.call(row["e-mail"])
        ids = ext_id && selectline_member_ids[ext_id]
        if ids&.one?
          person = Person.find_by(id: ids.first + MEMBER_ID_OFFSET)
          puts "Member #{ids.first} (ext_id #{ext_id}) was not imported" unless person
          person
        elsif email
          puts "Unknown or ambiguous ext_id #{ext_id}, matching by email #{email}" if ext_id
          Person.find_by(email:)
        end
      end

      sales_point_attrs = lambda do |row, prefix|
        # mostly addresses, sometimes with the name of the shop
        address = text.call(row["#{prefix}verkaufsstelle"])
        email = text.call(row["#{prefix}verkaufsstelle_email_adresse"])
        phone = text.call(row["#{prefix}verkaufsstelle_telefonnummer"])
        # the phone column contains email addresses in some rows
        if phone&.include?("@")
          email ||= phone
          phone = nil
        end
        {address:, email:, phone:}.compact.presence
      end

      attach_image = lambda do |profile, value|
        url = value.to_s.split(",").map(&:strip).find(&:present?)
        return if url.blank? || ENV["SKIP_IMAGES"].present?

        profile.background_image.attach(io: URI.parse(url).open, # rubocop:disable Security/Open
          filename: File.basename(URI.parse(url).path))
      rescue => e
        puts "  could not download background image #{url}: #{e.message}"
      end

      stats = Hash.new(0)
      CSV.foreach(args[:path], headers: true, encoding: "bom|utf-8") do |row|
        stats[:total] += 1
        person = find_person.call(row)
        unless person
          stats[:person_missing] += 1
          puts "No person found for ext_id #{row["ext_id"]} / #{row["e-mail"]}"
          next
        end
        stats[:not_siegelimker] += 1 unless person.siegelimker?

        email = text.call(row["e-mail"])
        if person.email.blank? && email
          person.email = email
          person.validate
          if person.errors[:email].present?
            puts "Person #{person.id}: not setting email #{email}: #{person.errors[:email].join(", ")}"
            person.email = nil
          else
            # other errors are ignored, some members were imported without zip validation
            person.save!(validate: false)
            stats[:email_set] += 1
          end
        end

        profile = person.siegelimker_profile || person.build_siegelimker_profile
        profile.assign_attributes(
          public_profile: boolean.call(row["oeffentliches_profil"]),
          title: text.call(row["titel_der_imkerei"]),
          description: text.call(row["description"]),
          website: text.call(row["webseite"]),
          public_offer: boolean.call(row["oeffentlich_angebot_anzeigen"]),
          further_information: text.call(row["weitere_informationen"]),
          **products.to_h do |product, column|
            [:"#{product}_availability", availabilities.fetch(text.call(row[column]), "not_offered")]
          end,
          **SiegelimkerProfile::BEE_LOCATIONS.zip(prefixes).to_h do |attr, prefix|
            [attr, text.call(row["#{prefix}bienen-standort"])]
          end
        )
        profile.sales_points.each(&:mark_for_destruction)
        prefixes.filter_map { |prefix| sales_point_attrs.call(row, prefix) }
          .each { |attrs| profile.sales_points.build(attrs) }
        attach_image.call(profile, row["background_image"])
        # keep the coordinates of the website until the address changes,
        # profiles without coordinates are geocoded when saving
        lat = text.call(row["map_lat"])
        lng = text.call(row["map_lng"])
        profile.assign_geocoded_coordinates(lat, lng) if lat && lng

        unless profile.valid?
          # drop invalid values instead of skipping the whole profile
          puts "Person #{person.id}: dropping invalid #{profile.errors.full_messages.join(", ")}"
          profile.sales_points.each do |sales_point|
            sales_point.email = nil if sales_point.errors.include?(:email)
          end
          (profile.errors.attribute_names & profile.attribute_names.map(&:to_sym))
            .each { |attr| profile[attr] = nil }
        end

        begin
          if profile.save
            stats[:imported] += 1
          else
            stats[:failed] += 1
            puts "Person #{person.id}: #{profile.errors.full_messages.join(", ")}"
          end
        rescue Seahorse::Client::NetworkingError => e
          puts e.message
          puts row["background_image"]
        end
      end

      puts stats.map { |key, count| "#{key}: #{count}" }.join(", ")
    end

    desc "Import the events organized by apiservice from the website CSV export " \
         "into the apiservice group below the Dachverband"
    task :apiservice_events, [:path] => :environment do |_, args|
      require "csv"

      failure_csv = "invalid_apiservice_events.csv"
      group = Group.root.children.find_by!(type: Group::Apiservice.sti_name)
      text = ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }
      boolean = ->(value) { value.to_s.strip == "Ja" }
      # the export uses Europe/Vaduz, which has the same offsets as the app's Bern time zone
      parse_time = lambda do |date, time, all_day|
        date = text.call(date)
        return nil unless date

        # all day events are stored without time, hitobito then only shows the date
        time = all_day ? nil : text.call(time)
        Time.zone.parse([date, time].compact.join(" "))
      end
      # custom fields of the website, there are no corresponding event attributes in hitobito
      additional_infos = {
        "Zielgruppe" => "additional:_ecp_custom_2 (Zielgruppe)",
        "Referent" => "additional:_ecp_custom_5 (Referent)",
        "Besuchsmöglichkeit" => "additional:_ecp_custom_7 (Besuchsmöglichkeit)",
        "Kontakt" => "additional:_ecp_custom_30 (Kontakt)",
        "Sektion" => "additional:_ecp_custom_35 (Section)",
        "Veranstalter" => "organizer_names",
        "Website" => "event_website"
      }

      stats = Hash.new(0)
      failed_rows = []
      headers = nil
      CSV.foreach(args[:path], headers: true, col_sep: ";", encoding: "bom|utf-8") do |row|
        headers ||= row.headers
        stats[:total] += 1
        # for now only events organized by apiservice are imported
        unless row["organizer_names"].to_s.split(/[|,]/).map(&:strip).include?("apiservice")
          stats[:other_organizer] += 1
          next
        end

        # the website event ids are already in their own range (10_000_000 + occurrence id),
        # so they are used as they are to keep the import idempotent
        event = Event.where(id: Integer(row["event_id"])).first_or_initialize
        event.groups = [group]
        event.name = text.call(row["title"])

        infos = additional_infos.filter_map do |label, column|
          value = text.call(row[column])
          next if value.nil? || value == "Keine Sektion"

          value = value.tr("|", ", ") if label == "Zielgruppe"
          "#{label}: #{value}"
        end
        event.description = [text.call(row["description"]), infos.join("\n").presence]
          .compact.join("\n\n")

        event.location = [
          text.call(row["venue"]),
          text.call(row["venue_address"]),
          [text.call(row["venue_postcode"]), text.call(row["venue_city"])]
            .compact.join(" ").presence,
          (text.call(row["venue_country"]) unless text.call(row["venue_country"]) == "Switzerland")
        ].compact.join("\n").presence

        cost = text.call(row["cost"])
        # prefix numeric costs with the currency, keep texts like "Kostenlos" as they are
        if cost&.match?(/\A[\d.]+\z/)
          cost = [text.call(row["currency_code"]), cost].compact.join(" ")
        end
        event.cost = cost

        all_day = boolean.call(row["all_day"])
        start_at = parse_time.call(row["start_date"], row["start_time"], all_day)
        finish_at = parse_time.call(row["end_date"], row["end_time"], all_day)
        date = event.dates.first || event.dates.build
        date.start_at = start_at
        date.finish_at = (finish_at if finish_at && finish_at > start_at)

        event.save!
        stats[:imported] += 1
      rescue => e
        stats[:failed] += 1
        puts "Row #{stats[:total]} (event #{row["event_id"]}, #{row["title"]}): #{e.message}"
        failed_rows << row.fields + [e.message]
      end

      CSV.open(failure_csv, "w", write_headers: true, headers: headers.to_a + ["error"]) do |csv|
        failed_rows.each { |fields| csv << fields }
      end
      puts stats.map { |key, count| "#{key}: #{count}" }.join(", ")
      puts "Failed rows written to #{failure_csv}" if failed_rows.any?
    end

    desc "Delete all files in the S3 bucket of the active storage service " \
         "(run before a full import, the import recreates all attachments)"
    task clear_storage_bucket: :environment do
      service = ActiveStorage::Blob.service
      # S3Service is only loaded when it is configured, so check for its bucket instead
      unless service.respond_to?(:bucket)
        abort "Active storage service #{service.name} is not S3, " \
              "set RAILS_STORAGE_SERVICE=cloudscale"
      end

      puts "Deleting all #{service.bucket.objects.count} files in bucket #{service.bucket.name}"
      service.delete_prefixed("")
    end

    task reset_id_sequences: :environment do
      ActiveRecord::Base.connection.tables.each do |t|
        puts "Resetting primary key sequence for #{t}"
        ActiveRecord::Base.connection.reset_pk_sequence!(t)
      end
    end
  end
end
