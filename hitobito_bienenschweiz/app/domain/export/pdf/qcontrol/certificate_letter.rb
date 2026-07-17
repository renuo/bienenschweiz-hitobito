# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class CertificateLetter
    LOGO_WIDTH = 80
    # original logo is 138x112 px
    LOGO_HEIGHT = LOGO_WIDTH * 112.0 / 138
    SIGNATURE_WIDTH = 80
    # conservative height budget for cursor advancement after side-by-side signatures
    SIGNATURE_ADVANCE = 60
    FONT_SIZE = 10

    attr_reader :pdf, :qcontrol, :document

    def initialize(qcontrol)
      @document = Export::Pdf::Document.new(margin: [2.5.cm, 2.5.cm, 2.5.cm, 2.5.cm])
      @pdf = @document.pdf
      @pdf.font_size(FONT_SIZE)
      @qcontrol = qcontrol
    end

    def draw_all
      draw_logo
      draw_address
      draw_date
      draw_title
      draw_body
      draw_signatures
      pdf.start_new_page
    end

    def render
      draw_all
      pdf.render
    end

    def self.filename(qcontrol)
      parts = ["zertifikatsbrief", qcontrol.person&.full_name,
        qcontrol.control_date&.strftime("%Y-%m-%d")].compact
      "#{parts.join("-").parameterize(separator: "_")}.pdf"
    end

    private

    def person
      qcontrol.person
    end

    def t(key, **opts)
      I18n.t("certificate_letter.#{key}", **opts)
    end

    def draw_logo
      pdf.image(logo_path, at: [pdf.bounds.width - LOGO_WIDTH, pdf.cursor], width: LOGO_WIDTH)
      pdf.move_down(LOGO_HEIGHT + 16)
    end

    def logo_path
      HitobitoBienenschweiz::Wagon.root.join("app/assets/images/logo_bw.png").to_s
    end

    def draw_address
      address_lines.each { |line| pdf.text(line) }
      pdf.move_down(20)
    end

    def address_lines
      [person&.salutation, person_name, person_street, person_city].compact_blank
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

    def draw_date
      date_str = qcontrol.control_date ? I18n.l(qcontrol.control_date, format: "%B %Y") : ""
      pdf.text(t("date", date: date_str), align: :right)
      pdf.move_down(14)
    end

    def draw_title
      pdf.text(t("title"), size: 13, style: :bold)
      pdf.move_down(10)
    end

    def draw_body
      t("text").split(/\n\n+/).each do |paragraph|
        pdf.text(paragraph.strip)
        pdf.move_down(8)
      end
      pdf.move_down(4)
    end

    def draw_signatures
      pdf.text(t("signature_title"), style: :bold)
      pdf.move_down(12)

      sig_width = pdf.bounds.width / 2.0
      top = pdf.cursor
      I18n.t("certificate_letter.signatures").each_with_index do |sig, i|
        draw_signature(sig, i, sig_width, top)
      end
      pdf.move_down(SIGNATURE_ADVANCE)
    end

    def draw_signature(sig, index, sig_width, top)
      pdf.bounding_box([index * sig_width, top], width: sig_width) do
        pdf.move_down(44)
        pdf.text(sig[:name], style: :bold)
        pdf.text(sig[:title])
      end
    end
  end
end
