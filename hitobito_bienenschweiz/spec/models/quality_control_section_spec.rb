# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe QualityControlSection do
  describe ".version" do
    it "returns 1 for dates before 2020" do
      expect(described_class.version(Date.new(2019, 12, 31))).to eq(1)
    end

    it "returns 2 for dates between 2020 and June 2024" do
      expect(described_class.version(Date.new(2023, 1, 1))).to eq(2)
    end

    it "returns 2 for date just before the cutoff" do
      expect(described_class.version(Date.new(2024, 5, 31))).to eq(2)
    end

    it "returns 3 for dates on or after June 2024" do
      expect(described_class.version(Date.new(2024, 6, 1))).to eq(3)
    end

    it "returns 3 for current dates" do
      expect(described_class.version).to eq(3)
    end
  end
end
