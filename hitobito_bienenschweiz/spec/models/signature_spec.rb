# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Signature do
  let(:signature) { signatures(:certificate_letter_1) }

  describe "validations" do
    it "is valid with a key and a name" do
      expect(Fabricate.build(:signature)).to be_valid
    end

    it "requires a key" do
      expect(Fabricate.build(:signature, key: nil)).not_to be_valid
    end

    it "requires a unique key" do
      expect(Fabricate.build(:signature, key: signature.key)).not_to be_valid
    end

    it "requires a name" do
      expect(Fabricate.build(:signature, name: nil)).not_to be_valid
    end
  end

  describe "#to_s" do
    it "returns the name" do
      expect(signature.to_s).to eq(signature.name)
    end
  end

  describe "#remove_image" do
    it "always returns false" do
      expect(signature.remove_image).to eq(false)
    end
  end

  describe "#remove_image=" do
    before do
      signature.image.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "signature.png", content_type: "image/png"
      )
    end

    it "purges the image when set to a truthy value" do
      expect { signature.remove_image = "1" }
        .to change { signature.image.attached? }.from(true).to(false)
    end

    it "keeps the image when set to a falsy value" do
      expect { signature.remove_image = "0" }
        .not_to change { signature.image.attached? }.from(true)
    end
  end
end
