# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe DiplomaMailer, type: :mailer do
  let(:kind) { Fabricate(:event_kind) }
  let(:event) do
    Fabricate(:course, kind: kind, groups: [groups(:root)],
      diploma_location: "Bern",
      diploma_issued_at: Date.new(2026, 6, 20))
  end

  describe "#order" do
    subject(:mail) { described_class.order(event) }

    it "sends to PRINTER_EMAIL" do
      expect(mail.to).to eq([DiplomaMailer::PRINTER_EMAIL])
    end

    it "includes event name and date in subject" do
      expect(mail.subject).to include(event.name)
      expect(mail.subject).to include("Juni 2026")
    end

    it "attaches diploma PDF" do
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq(Export::Pdf::Event::Diploma.filename(event))
      expect(mail.attachments.first.content_type).to include("application/pdf")
    end

    context "when diploma_issued_at is nil" do
      let(:event) do
        Fabricate(:course, kind: kind, groups: [groups(:root)],
          diploma_location: "Bern",
          diploma_issued_at: nil)
      end

      it "uses hyphen in subject instead of date" do
        expect(mail.subject).to include("-")
      end

      it "does not raise" do
        expect { mail }.not_to raise_error
      end
    end
  end
end
