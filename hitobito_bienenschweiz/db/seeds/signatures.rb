#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

[
  {key: "certificate_letter_1", name: "Martin Schwegler", title: "Zentralpräsident"},
  {key: "certificate_letter_2", name: "Markus Michel", title: "Ressort Bienenprodukte"},
  {key: "diploma_official", name: "Markus Michel", title: "Leiter Ressort Bildung"}
].each do |attrs|
  Signature.find_or_create_by!(key: attrs[:key]) do |sig|
    sig.name = attrs[:name]
    sig.title = attrs[:title]
  end
end
