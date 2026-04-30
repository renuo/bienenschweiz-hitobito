namespace :import do
  task :mv => :environment do
    puts ENV["MV_DATABASE_URL"]

    admin = Person.find(1)
    group = Group.find(1)
    role_type = Group::Root::Mitglied
    class MvRecord < ApplicationRecord
      self.abstract_class = true
      connects_to database: {reading: :mv, writing: :mv}
    end

    class Member < MvRecord
    end
    total_count = 0
    success_count = 0
    email_duplicate_count = 0

    Member.limit(100000).find_each do |member|
      total_count += 1
      new_id = member.id + 1000 # offset by 1000 to not conflict with admin or test data
      person = Person.where(id: new_id).first_or_initialize do |person|
        person.id = new_id
      end
      begin
        person.first_name = member.firstname
        person.last_name = member.lastname
        person.address_care_of = [member.affix_1, member.affix_2, member.affix_3].compact.join(", ")
        person.street = member.street
        person.housenumber = member.house_no
        person.postbox = [member.pobox, member.pobox_zip, member.pobox_zip_ex].compact.join(", ")
        person.salutation = member.salutation
        person.hive_count = member.hive_count
        person.honey_yield = member.honey_yield
        person.zip_code = member.zip
        person.town = member.location
        person.country = ISO3166::Country[member.country_key].translations['de']
        person.email = member.email_contacts.first
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
        PeopleManager.where(managed: person, manager: admin).first_or_create!
        person.roles.create!(type: role_type.sti_name, group: group, start_on: 1.year.ago)
        success_count += 1
      rescue StandardError => e
        puts "--- Error importing member #{member.id}: #{e.message}"
        # puts e.backtrace
        p member
        p person
        if person.errors[:email].present?
          p person.errors[:email]
          email_duplicate_count += 1
        end
        puts "\n"
      end
    end
    puts "Imported #{success_count}/#{total_count} members (email duplicate: #{email_duplicate_count})"
  end
end
