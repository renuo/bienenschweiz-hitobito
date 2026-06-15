# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    class ControlInfo < Section
      GROUP_LABEL_WIDTH = 100
      LABEL_WIDTH = 60

      def render
        info_table(control_rows)
        separator
        info_table(beekeeper_rows)
        separator
        info_table(inspector_rows)
        separator
      end

      private

      def control_rows
        [[bold(t("control_title")), label("date"), bold(l(qcontrol.control_date)),
          label("section_no"), bold(group.code)]]
      end

      def beekeeper_rows
        [name_row, address_row, contact_row]
      end

      def name_row
        [bold(t("beekeeper_data")), label("first_name"), bold(person&.first_name),
          label("last_name"), bold(person&.last_name)]
      end

      def address_row
        ["", label("street"), bold(street), label("city"), bold(city)]
      end

      def contact_row
        ["", label("email"), bold(person&.email), label("tel"), bold(phone)]
      end

      def inspector_rows
        [[bold(t("inspector_data")), label("first_name"), bold(inspector&.first_name),
          label("last_name"), bold(inspector&.last_name)]]
      end

      def info_table(rows)
        table(rows, column_widths: column_widths,
          cell_style: {borders: [], padding: [1, 2, 1, 0]})
      end

      def column_widths
        value_width = (bounds.width - GROUP_LABEL_WIDTH - (2 * LABEL_WIDTH)) / 2.0
        [GROUP_LABEL_WIDTH, LABEL_WIDTH, value_width, LABEL_WIDTH, value_width]
      end

      def label(key)
        "#{t(key)}:"
      end

      def bold(content)
        {content: content.to_s, font_style: :bold}
      end

      def street
        [person&.street, person&.housenumber].compact_blank.join(" ")
      end

      def city
        [person&.zip_code, person&.town].compact_blank.join(" ")
      end

      def phone
        person&.phone_numbers&.first&.number
      end
    end
  end
end
