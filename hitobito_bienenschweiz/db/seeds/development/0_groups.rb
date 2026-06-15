# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.


require Rails.root.join("db", "seeds", "support", "group_seeder")

seeder = GroupSeeder.new

root = Group.roots.first
srand(42)

if root.address.blank?
  root.update(seeder.group_attributes)
  root.default_children.each do |child_class|
    child_class.first.update(seeder.group_attributes)
  end
end

# uncomment this if you want to load the spec fixtures
# ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('../hitobito_bienenschweiz/spec/fixtures'), 'groups')

Group::Kantonalverband.seed_once(:id, {
  id: 10128,
  parent_id: root.id,
  name: "Aargauer Kantonalverband",
  code: 1900
}, {
  id: 10017,
  parent_id: root.id,
  name: "Berner Kantonalverband",
  code: 200
})

aargauer_kantonalverband = Group::Kantonalverband.find(10128)
berner_kantonalverband = Group::Kantonalverband.find(10017)

Group::Sektion.seed_once(:id, {
  id: 10139,
  parent_id: aargauer_kantonalverband.id,
  name: "Aarau und Umgebung",
  code: 1911
}, {
  id: 10034,
  parent_id: berner_kantonalverband.id,
  name: "Aarberg",
  code: 217,
})

Group.rebuild!
