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
              content_type: mv_qcontrol.content_type
            )
            qcontrol.save(validate: false)
            f.close
          rescue StandardError => e
            puts "Error attaching document for qcontrol #{qcontrol.id}: #{e.message}"
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
      MvSupervision.find_each do |mv_supervision|
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
      puts "Imported #{count} supervisions"

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
      MvDocument.find_each do |mv_document|
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
      puts "Imported #{count} documents"

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
      MvMemo.find_each do |mv_memo|
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
      puts "Imported #{count} memos"

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

      kas_fees.includes(:fee_type).find_each do |kas_fee|
        kind = kas_fee_types[kas_fee.fee_type.title]
        kind_id = event_kinds[kind]
        group_id = kas_fee.intern_structure_id + GROUP_ID_OFFSET
        date = Event::Date.new(start_at: kas_fee.occurred_on)
        key = [kind_id, group_id, kas_fee.occurred_on]
        merge_count += 1 if courses.key?(key)

        course = courses[key] ||= Event::Course.create!(
          name: "#{kas_fee.fee_type.title} #{kas_fee.occurred_on.strftime("%d.%m.%Y")}",
          location: kas_fee.place, cost: kas_fee.total_amount,
          kind_id: kind_id, group_ids: [group_id], dates: [date]
        )
        participation = course.participations.create!(
          participant_id: kas_fee.user.member_id + MEMBER_ID_OFFSET,
          participant_type: Person.sti_name, active: true
        )
        role = kind == "Basiskurs Imkern" ? Event::Role::Leader : Event::Course::Role::Participant
        participation.roles.create!(type: role.sti_name)
        import_count += 1
      rescue StandardError => e
        puts "Error importing fee #{kas_fee.id}: #{e.message}"
      end

      puts "Imported #{import_count} and grouped #{merge_count} courses"
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
      CSV.foreach(args[:path], headers: true, encoding: "bom|utf-8") do |row|
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
    end

    desc "Import website profiles of Siegelimker from the website CSV export " \
         "(set SKIP_IMAGES=1 to skip downloading background images)"
    task :siegelimker_profiles, [:path] => :environment do |_, args|
      require "csv"
      require "open-uri"

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
        year = text.call(row["siegelimker_seit_jahr"])
        profile.assign_attributes(
          public_profile: boolean.call(row["oeffentliches_profil"]),
          title: text.call(row["titel_der_imkerei"]),
          siegelimker_since: (year.to_i if year&.match?(/\A\d{4}\z/)),
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

        if profile.save
          stats[:imported] += 1
        else
          stats[:failed] += 1
          puts "Person #{person.id}: #{profile.errors.full_messages.join(", ")}"
        end
      end

      puts stats.map { |key, count| "#{key}: #{count}" }.join(", ")
    end

    task reset_id_sequences: :environment do
      ActiveRecord::Base.connection.tables.each do |t|
        puts "Resetting primary key sequence for #{t}"
        ActiveRecord::Base.connection.reset_pk_sequence!(t)
      end
    end
  end
end
