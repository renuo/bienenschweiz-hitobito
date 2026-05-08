namespace :mv do
  namespace :import do

    task :members => :environment do
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
      failed_members = {}

      scope = Member.all.includes(:login)
      # scope = scope.limit(100)
      scope.find_each do |member|
        total_count += 1
        new_id = member.id + 1000 # offset by 1000 to not conflict with admin or test data
        person = Person.where(id: new_id).first_or_initialize do |person|
          person.id = new_id
        end
        begin
          person.first_name = member.firstname
          person.last_name = member.lastname
          person.address_care_of = [member.affix_1, member.affix_2, member.affix_3].map(&:presence).compact.join(", ")
          person.street = member.street
          person.housenumber = member.house_no
          person.postbox = [member.pobox, member.pobox_zip, member.pobox_zip_ex].map(&:presence).compact.join(", ")
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
          person.save!
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
               :headers => ["id", "selectline_number", "error"]
      ) do |csv|
        failed_members.each do |m, error|
          csv << [m.id, m.selectline_customer_number, error]
        end
      end
      puts "Imported #{success_count}/#{total_count} members (email duplicate: #{email_duplicate_count})"
    end
    task :groups => :environment do
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
          group.id = verband.id + 1000 # offset by 1000 to not conflict with admin or test data
        end
        group.parent = root_group
        group.created_at = verband.created_at
        group.updated_at = verband.updated_at
        group.save!
        try_add_website(group, verband)
      end

      InternStructure.where(structure_type: InternStructure.structure_types[:sektion]).find_each do |sektion|
        group = Group::Sektion.where(name: sektion.name).first_or_initialize do |group|
          group.id = sektion.id + 1000
        end
        group.parent = Group::Kantonalverband.find(sektion.parent_id + 1000)
        group.created_at = sektion.created_at
        group.updated_at = sektion.created_at
        group.save!
        try_add_website(group, sektion)
      end
    end

    def try_add_website(group, intern_structure)
      if intern_structure.url.present?
        group.social_accounts.where(label: :Website, name: intern_structure.url).first_or_create!
      end
    end

    def find_role(membership)
      ad_roles = ['SI_We', 'SI_WE', 'SI WE', 'SI_WE 2020'] # the different spellings are for different years ...
      if ad_roles.include?(membership.role.name_t)
        # needs to be mapped to num_ad_boards later??
        return -1
      end
      # this one isn't included in the mapping table at all. shows up on verein and sektion
      return nil if membership.role.name_t == 'Ansprechsperson Asiatische Hornisse'
      case membership.intern_structure.structure_type
      when "verband"
        case membership.role.name_t
        when "P", "KP"
          Group::Kantonalverband::Kantonalpraesidentin
        when "K"
          Group::Kantonalverband::Kassier
        when "B", "B-PROV", "H", "Z", "Z-PROV", "SI", 'SI-PROV'
          # only exists on Sektion.
        when "INSP", "B-INFO", "SU"
          # only exists on Verein
        when "BO"
          Group::Kantonalverband::Bildungsobperson
        when "ZO"
          Group::Kantonalverband::Zuchtobperson
        when "HO"
          Group::Kantonalverband::Honigobperson
        when "HO-PROV"
          Group::Kantonalverband::HonigobpersonProvisorisch
        when "H-PROV"
          # only exists on Sektion
        when "INS", "KP-prov"
          # marked as archived and ignored
          return -1
        when /IB_(\d+|F)/, 'Kaderkurs 0'
          # needs to be mapped to courses later
          return -1
        when "FA", "FA_F", "IK", "BS_EK", /BS_VK_B\d/
          # needs to be mapped to qualifications later
          return -1
        when "EV"
          # only exists on Sektion now
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for verband"
        end
      when "sektion"
        case membership.role.name_t
        when "B"
          Group::Bildung::FachpersonBildung
        when "B-PROV"
          Group::Bildung::FachpersonBildungInAusbildung
        when "Z"
          Group::Zucht::FachpersonZucht
        when "Z-PROV"
          Group::Zucht::FachpersonZuchtInAusbildung
        when "P"
          Group::Sektion::Praesident
        when "K"
          Group::Sektion::Kassier
        when "H"
          Group::Produkte::FachpersonProdukte
        when "H-PROV"
          Group::Produkte::FachpersonProdukteInAusbildung
        when "SI"
          Group::Sektion::Siegelimker
        when "SI-PROV"
          Group::Sektion::SiegelimkerProvisorisch
        when "EV"
          Group::Sektion::ErfassungVeranstaltungen
        when "HAN", "INS", "BEA", 'SM'
          # marked as archived and ignored
          return -1
        when /IB_\d+/, 'Kaderkurs 0'
          # needs to be mapped to courses later
          return -1
        when "INSP"
          # only exists on Verein
        when "KP"
          # only exists on Verband
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for sektion"
        end
      when "verein"
        case membership.role.name_t
        when "sekretariat", "HAN", 'Mitglied Kontrollstelle', "INS", 'HK'
          # marked as archived and ignored
        when "A"
          Group::Dachverband::AdministratorBienenSchweiz
        when "SU"
          Group::Dachverband::Supervisor
        when "EP"
          Group::Ehrenpersonen::Ehrenpraesident
        when "EM"
          Group::Ehrenpersonen::Ehrenmitglied
        when "ZV"
          Group::Zentralvorstand::Mitglied
        when 'Mitglied VDRB' # Probably?
          Group::BeraterInfo::Mitglied
        when 'INSP'
          Group::Inspektion::Inspektor
        when "EV", 'SI'
          # only exists on Sektion now
        when 'H-PROV'
          # only exists on Verband
        else
          raise "Unspecified role #{membership.role.name_t} (#{membership.role.name}) for verein"
        end
      else
        raise "Unsupported structure type #{membership.intern_structure.structure_type}"
      end
    end

    task :roles => :environment do
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
        belongs_to :role, class_name: "MvRole", foreign_key: :role_id
        belongs_to :intern_structure
      end

      admin = Person.find(1)
      scope = Membership
      total = scope.count
      mapped_count = 0
      unknown_mappings = []
      scope.includes(:role).find_each do |membership|
        begin
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
          group = membership.intern_structure.verein? ? Group.root : Group.find(membership.intern_structure_id + 1000)
          person = Person.find(membership.member_id + 1000)
          if group.is_a? group_class
            # puts "Matched #{group_class}"
          else
            group = group.children.where(type: group_class.sti_name).first
          end
          # puts "Adding to #{group.inspect}"

          # TODO: do we need/want this?
          # PeopleManager.where(managed: person, manager: admin).first_or_create!

          role_id = membership.id + 1000
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
      end
      puts "Mapped #{mapped_count}/#{total} roles"
      puts "#{unknown_mappings.count} unknown mappings:"
      unknown_mappings.each do |role, structure_type|
        puts "#{role.name} (#{role.name_t}) on #{structure_type}"
      end
    end
  end
end
