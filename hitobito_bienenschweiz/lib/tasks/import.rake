namespace :import do
  task :mv => :environment do
    failure_csv = 'invalid_members.csv'
    admin = Person.find(1)
    group = Group.find(1)
    role_type = Group::Root::Mitglied
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
        @@users ||= User.all.to_h{|u| [u.member_id, u]}
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
        person.country = ISO3166::Country[member.country_key].translations['de']
        person.email = (member.login || member.kas_user)&.email
        member.email_contacts.each do |email|
          unless email == person.email
            person.additional_emails.where(email:,label: "Private").first_or_initialize
          end
        end
        person.birthday = member.birthdate
        person.export_to_website = member.typo3_export
        if key = member.lang_key
          person.language = {D: 'de', E: 'en', F: 'fr', I: 'it'}.fetch(key&.to_sym)
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
        if person.roles.empty?
          PeopleManager.where(managed: person, manager: admin).first_or_create!
          person.roles.create!(type: role_type.sti_name, group: group, start_on: 1.year.ago)
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
    CSV.open(failure_csv,'w',
             write_headers: true,
             :headers => ['id','selectline_number','error']
    ) do |csv|
      failed_members.each do |m, error|
        csv << [m.id, m.selectline_customer_number, error]
      end
    end
    puts "Imported #{success_count}/#{total_count} members (email duplicate: #{email_duplicate_count})"
  end
end
