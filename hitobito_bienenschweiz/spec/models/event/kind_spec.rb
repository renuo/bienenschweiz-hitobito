# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Event::Kind do
  describe "kas fee type mutual exclusion" do
    subject(:kind) { Fabricate.build(:event_kind) }

    it "is valid with only kas_fixed_fee enabled" do
      kind.kas_fixed_fee = true
      kind.kas_instructor_fees = false
      expect(kind).to be_valid
    end

    it "is valid with only kas_instructor_fees enabled" do
      kind.kas_fixed_fee = false
      kind.kas_instructor_fees = true
      expect(kind).to be_valid
    end

    it "is valid with both disabled" do
      kind.kas_fixed_fee = false
      kind.kas_instructor_fees = false
      expect(kind).to be_valid
    end

    it "is invalid with both kas_fixed_fee and kas_instructor_fees enabled" do
      kind.kas_fixed_fee = true
      kind.kas_instructor_fees = true
      expect(kind).not_to be_valid
      expect(kind.errors[:kas_instructor_fees]).to be_present
    end
  end
end
