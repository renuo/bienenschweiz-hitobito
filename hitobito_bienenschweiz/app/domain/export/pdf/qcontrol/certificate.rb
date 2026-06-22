# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  # Generates a minimal PDF with name, address and control date placed at the
  # exact coordinates of the original XForms certificate template (formerly
  # filled via XFDF/pdftk). Intended for printing on top of pre-printed
  # special certificate paper.
  #
  # Coordinates (PDF user space, origin bottom-left of A4 page) are derived
  # from the XObject bounding boxes in certificate-form.pdf:
  #   name        HeBo 20pt  at (193.66, 504.69)
  #   street      HeBo 18pt  at (193.66, 481.29)
  #   ziplocation HeBo 18pt  at (193.66, 458.97)
  #   controldate Helv 14pt  at (179.05, 236.06)
  class Certificate
    NAME_AT = [193.66, 504.69].freeze
    STREET_AT = [193.66, 481.29].freeze
    CITY_AT = [193.66, 458.97].freeze
    DATE_AT = [179.05, 236.06].freeze

    NAME_SIZE = 20
    ADDRESS_SIZE = 18
    DATE_SIZE = 14

    def initialize(qcontrol, document: nil)
      @document = document || Export::Pdf::Document.new(margin: [0, 0, 0, 0])
      @pdf = @document.pdf
      @qcontrol = qcontrol
    end

    def render
      draw_address
      draw_date
      @pdf.render
    end

    def self.filename(qcontrol)
      parts = ["zertifikat", qcontrol.person&.full_name,
        qcontrol.control_date&.strftime("%Y-%m-%d")].compact
      "#{parts.join("-").parameterize(separator: "_")}.pdf"
    end

    private

    def person
      @qcontrol.person
    end

    def draw_address
      @pdf.font("NotoSans", style: :bold) do
        @pdf.draw_text(person_name, at: NAME_AT, size: NAME_SIZE)
        @pdf.draw_text(person_street, at: STREET_AT, size: ADDRESS_SIZE)
        @pdf.draw_text(person_city, at: CITY_AT, size: ADDRESS_SIZE)
      end
    end

    def draw_date
      @pdf.font("NotoSans") do
        @pdf.draw_text(formatted_date, at: DATE_AT, size: DATE_SIZE)
      end
    end

    def person_name
      [person&.first_name, person&.last_name].compact_blank.join(" ")
    end

    def person_street
      [person&.street, person&.housenumber].compact_blank.join(" ")
    end

    def person_city
      [person&.zip_code, person&.town].compact_blank.join(" ")
    end

    def formatted_date
      @qcontrol.control_date ? I18n.l(@qcontrol.control_date, format: :long) : ""
    end
  end
end
