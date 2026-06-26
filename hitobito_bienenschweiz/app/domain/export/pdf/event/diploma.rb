# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Event
  # Generates one diploma page per active course participant.
  # Layout mirrors the "Vorlage Diplom Grundkurs neu" Word template:
  #   - top ~45 % of page is intentionally blank (reserved for printed letterhead)
  #   - centred bold name + city
  #   - justified body paragraphs
  #   - signature row 1: up to 2 dynamic leaders + fixed BienenSchweiz official
  #   - signature row 2: dynamic leaders 3 and 4 (when present)
  class Diploma
    FONT_SIZE = 11
    NAME_SIZE = 16
    CITY_SIZE = 14
    TOP_BLANK = 100.mm
    SIG_ROW_SPACING = 12
    SIG_NAME_SPACING = 30

    def initialize(event)
      @event = event
      @document = Export::Pdf::Document.new(margin: [2.5.cm, 2.5.cm, 2.5.cm, 2.5.cm])
      @pdf = @document.pdf
      @pdf.font_size(FONT_SIZE)
    end

    def render
      participant_participations.each_with_index do |participation, index|
        @pdf.start_new_page if index > 0
        render_page(participation.person)
      end
      @pdf.render
    end

    def self.filename(event)
      "diplome_#{event.name.parameterize(separator: "_")}.pdf"
    end

    private

    attr_reader :event, :pdf

    def render_page(person)
      pdf.move_down(TOP_BLANK)
      render_participant(person)
      render_body
      render_date_line
      render_sig_row_1
      render_sig_row_2 if leaders.length >= 3
    end

    def render_participant(person)
      pdf.text(person_name(person), size: NAME_SIZE, style: :bold, align: :center)
      pdf.text(person_city(person), size: CITY_SIZE, style: :bold, align: :center)
      pdf.move_down(16)
    end

    def render_body
      section_names = event.groups.map(&:name).join(", ")
      course_name = event.kind&.label || event.name
      pdf.text(t("body", sections: section_names, course: course_name), align: :justify)
      pdf.move_down(10)
      pdf.text(t("congratulations"), align: :justify)
      pdf.move_down(28)
    end

    def render_date_line
      parts = [event.diploma_location.presence, formatted_diploma_date].compact_blank
      pdf.text(parts.join(", "))
      pdf.move_down(44)
    end

    def render_sig_row_1
      col_width = pdf.bounds.width / 3.0
      top = pdf.cursor
      render_leader_sig(leaders[0], 0, top, col_width)
      render_leader_sig(leaders[1], col_width, top, col_width)
      render_fixed_official_sig(col_width * 2, top, col_width)
      pdf.move_down(SIG_ROW_SPACING * 3 + SIG_NAME_SPACING)
    end

    def render_sig_row_2
      col_width = pdf.bounds.width / 3.0
      top = pdf.cursor
      render_leader_sig(leaders[2], 0, top, col_width)
      render_leader_sig(leaders[3], col_width, top, col_width) if leaders[3]
    end

    def render_leader_sig(person, x, top, width)
      return unless person

      pdf.bounding_box([x, top], width: width) do
        pdf.move_down(SIG_NAME_SPACING)
        pdf.text(person_name(person), style: :bold)
        pdf.text(t("leader_title"))
      end
    end

    def render_fixed_official_sig(x, top, width)
      pdf.bounding_box([x, top], width: width) do
        pdf.move_down(SIG_NAME_SPACING)
        pdf.text(t("fixed_official_name"), style: :bold)
        pdf.text(t("fixed_official_title"))
      end
    end

    def participant_participations
      event.participations
        .active
        .joins(:roles)
        .where(event_roles: {type: Event::Course::Role::Participant.sti_name})
        .includes(:participant)
    end

    def leaders
      @leaders ||= event.participations
        .active
        .joins(:roles)
        .where(event_roles: {type: leader_role_types})
        .includes(:participant)
        .map(&:person)
        .compact
    end

    def leader_role_types
      [Event::Role::Leader.sti_name, Event::Role::AssistantLeader.sti_name]
    end

    def formatted_diploma_date
      event.diploma_issued_at ? I18n.l(event.diploma_issued_at, format: :long) : nil
    end

    def person_name(person)
      [person&.first_name, person&.last_name].compact_blank.join(" ")
    end

    def person_city(person)
      [person&.zip_code, person&.town].compact_blank.join(" ")
    end

    def t(key, **opts)
      I18n.t("event.diploma.#{key}", **opts)
    end
  end
end
