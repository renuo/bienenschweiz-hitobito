# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Export::Tabular::Events::List do
  let(:label) { "in Bienenzeitung anzeigen" }

  def csv_for(entries)
    CSV.parse(Export::Csv::Generator.new(described_class.new(entries)).call,
      col_sep: Settings.csv.separator.strip, headers: true)
  end

  it "defaults to false" do
    expect(Event.new.show_in_bienenzeitung).to eq false
  end

  it "exports the flag for events" do
    shown = Fabricate(:event, show_in_bienenzeitung: true)
    hidden = Fabricate(:event)

    csv = csv_for([shown, hidden])
    expect(csv.headers).to include(label)
    expect(csv[label]).to eq %w[ja nein]
  end

  it "exports the flag for courses" do
    course = Fabricate(:course, kind: Fabricate(:event_kind), show_in_bienenzeitung: true)

    csv = csv_for([course])
    expect(csv.first[label]).to eq "ja"
  end
end
