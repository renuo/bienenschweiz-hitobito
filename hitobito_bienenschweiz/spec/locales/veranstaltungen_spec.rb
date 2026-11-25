# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

# BienenSchweiz calls events "Veranstaltung" instead of "Anlass". The overrides live in
# config/locales/veranstaltungen.de.yml. This spec fails when the core (or another wagon
# file) introduces a new German translation mentioning "Anlass", so it can be overridden.
describe "German translations" do
  def flatten_translations(value, prefix = nil)
    case value
    when Hash
      value.flat_map { |key, child| flatten_translations(child, [prefix, key].compact.join(".")) }
    when Array
      value.each_with_index.flat_map { |child, i| flatten_translations(child, "#{prefix}[#{i}]") }
    when String
      [[prefix, value]]
    else
      []
    end
  end

  it "do not call events Anlass" do
    offending = flatten_translations(I18n.t(".", locale: :de))
      .select { |_key, text| text.match?(/Anl[aä]ss/i) }
      .map { |key, text| "#{key}: #{text}" }

    expect(offending).to be_empty,
      "Override these in config/locales/veranstaltungen.de.yml:\n#{offending.join("\n")}"
  end
end
