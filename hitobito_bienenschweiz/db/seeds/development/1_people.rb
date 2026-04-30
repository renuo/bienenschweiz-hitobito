# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.


require Rails.root.join("db", "seeds", "support", "person_seeder")

class BienenschweizPersonSeeder < PersonSeeder

  def amount(role_type)
    case role_type.name.demodulize
    when "Member" then 5
    else 1
    end
  end

end

renuoers = [
  "Christoph Hitz",
  "Raphael Nestler",
  "Michael Gerber"
]

devs = {
  "Customer Name" => "customer@email.com"
}
renuoers.each do |ren|
  devs[ren] = "#{ren.split.last.downcase.gsub("ü", "ue").gsub("ä", "ae")}@renuo.ch"
end

seeder = BienenschweizPersonSeeder.new

seeder.seed_all_roles

root = Group.root
devs.each do |name, email|
  seeder.seed_developer(name, email, root, Group::Dachverband::AdministratorBienenSchweiz)
end
