# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Supervision do
  describe "result/kind validation" do
    it "accepts a result belonging to the kind" do
      expect(Fabricate.build(:supervision, kind: "supervision", result: "fulfilled")).to be_valid
      expect(Fabricate.build(:supervision, kind: "feedback", result: "good")).to be_valid
    end

    it "rejects a result of another kind on create" do
      supervision = Fabricate.build(:supervision, kind: "feedback", result: "fulfilled")
      expect(supervision).not_to be_valid
      expect(supervision.errors[:result]).to include("ist für Kursfeedback nicht zulässig")
    end

    it "does not validate the combination on update to not break legacy data" do
      supervision = Fabricate(:supervision, kind: "supervision", result: "fulfilled")
      supervision.update_columns(kind: "feedback") # simulate legacy data

      expect(supervision.update(check_date: Date.yesterday)).to be(true)
    end
  end
end
