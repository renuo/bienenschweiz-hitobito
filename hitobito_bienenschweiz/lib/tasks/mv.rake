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

    task members: :environment do
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

      total_count = 0
      success_count = 0
      email_duplicate_count = 0
      import_without_validations = 0
      failed_members = {}

      scope = Member.all.includes(:login)
      scope = scope.limit(1000)
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
          person.country = ISO3166::Country[member.country_key].translations["de"]
          person.email = (member.login || member.kas_user)&.email
          member.email_contacts.each do |email|
            unless email == person.email
              person.additional_emails.where(email:, label: "Private").first_or_initialize
            end
          end
          person.birthday = member.birthdate
          person.export_to_website = member.typo3_export
          if key = member.lang_key
            person.language = {D: "de", E: "en", F: "fr", I: "it"}.fetch(key&.to_sym)
          end
          person.phone_numbers.where(number: member.phone1).first_or_initialize do |phone|
            phone.number = member.phone1
            phone.label = :private
          end
          person.phone_numbers.where(number: member.phone2).first_or_initialize do |phone|
            phone.number = member.phone2
            phone.label = :private
          end
          person.phone_numbers.where(number: member.mobile).first_or_initialize do |phone|
            phone.number = member.mobile
            phone.label = :mobile
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
          failed_members[member] = e.message
        end
      end
      CSV.open(failure_csv, "w",
        write_headers: true,
        headers: ["id", "selectline_number", "error"]) do |csv|
        failed_members.each do |m, error|
          csv << [m.id, m.selectline_customer_number, error]
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
      if intern_structure.url.present?
        group.social_accounts.where(label: :Website, name: intern_structure.url).first_or_create!
      end
    end

    def find_role(membership)
      ad_roles = ["SI_We", "SI_WE", "SI WE", "SI_WE 2020"] # the different spellings are for different years ...
      if ad_roles.include?(membership.role.name_t)
        # needs to be mapped to num_ad_boards later??
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
      scope.includes(:role).find_each do |membership|
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
        group_class = role_type.model_name.to_s.deconstantize.constantize
        group = membership.intern_structure.verein? ? Group.root : Group.find(membership.intern_structure_id + ::GROUP_ID_OFFSET)
        person = Person.find(membership.member_id + ::MEMBER_ID_OFFSET)
        if group.is_a? group_class
          # puts "Matched #{group_class}"
        else
          group = group.children.where(type: group_class.sti_name).first
        end
        # puts "Adding to #{group.inspect}"

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

    task :quality_controls, [:redo_docs] => :environment do |t, args|
      require 'carrierwave'

      class AssetUploader < CarrierWave::Uploader::Base
        def store_dir
          "uploads/#{model.class.to_s.pluralize.underscore.gsub('mv_','')}/#{model.member_id}/#{model.id}"
        end

        def remove!
          nil
        end
      end
      class MvRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: {reading: :mv, writing: :mv}
      end
      require 'carrierwave/orm/activerecord'

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

      MvQcontrol.find_each.map do |mv_qcontrol|
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
              content_type: mv_qcontrol.content_type,
            )
            qcontrol.save(validate: false)
            f.close
          end
        end
      end

      answer_rows = MvQualityControlAnswer.find_each.map do |answer|
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

    task reset_id_sequences: :environment do
      ActiveRecord::Base.connection.tables.each do |t|
        puts "Resetting primary key sequence for #{t}"
        ActiveRecord::Base.connection.reset_pk_sequence!(t)
      end
    end
  end
end
