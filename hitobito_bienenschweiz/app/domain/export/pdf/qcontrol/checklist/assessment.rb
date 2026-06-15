# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    class Assessment < Section
      def render
        type_of_control
        separator
        no_control_needed
        separator
        control_state
        separator
      end

      private

      def type_of_control
        title(t("type_of_control.title"))
        checkbox_row([
          [t("type_of_control.new_certification"), qcontrol.first_qcontrol?],
          [periodic_control_label, !qcontrol.first_qcontrol?]
        ])
        checkbox_row([
          [t("type_of_control.voucher_for_young_beekeeper"), qcontrol.with_voucher?]
        ])
      end

      def periodic_control_label
        [t("type_of_control.periodic_control"),
          l(qcontrol.previous_qcontrol&.control_date)].compact_blank.join(" ")
      end

      def no_control_needed
        title(t("no_control_needed.title"))
        checkbox_row([
          [t("no_control_needed.termination_of_business"),
            qcontrol.termination_of_business?],
          [t("no_control_needed.resignation_from_certification_program"),
            qcontrol.resignation_from_certification_program?],
          [t("no_control_needed.beekeeper_deceased"), qcontrol.beekeeper_deceased?]
        ])
      end

      def control_state
        title(t("control_state.title"))
        checkbox_row([
          [t("control_state.passed"), qcontrol.passed?],
          [t("control_state.partially_passed"), qcontrol.partially_passed?],
          [t("control_state.not_passed"), qcontrol.not_passed?]
        ])
        pdf.move_down(4)
        text(t("control_state.notice"), style: :italic)
      end
    end
  end
end
