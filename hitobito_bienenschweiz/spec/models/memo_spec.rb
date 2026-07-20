# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Memo do
  subject(:memo) { Fabricate.build(:memo) }

  it { is_expected.to be_valid }

  it "is invalid without a title" do
    memo.title = nil
    expect(memo).not_to be_valid
  end

  it "is invalid without a body" do
    memo.body = nil
    expect(memo).not_to be_valid
  end

  describe "#set_author_name" do
    it "stores the author's full name on create" do
      author = Fabricate(:person, first_name: "Jane", last_name: "Doe")
      memo = Fabricate(:memo, author: author)
      expect(memo.author_name).to eq(author.full_name)
    end

    it "leaves author_name nil when no author is set" do
      memo = Fabricate(:memo, author: nil)
      expect(memo.author_name).to be_nil
    end
  end

  describe "#to_s" do
    it "returns the title" do
      memo.title = "My Memo"
      expect(memo.to_s).to eq("My Memo")
    end
  end
end
