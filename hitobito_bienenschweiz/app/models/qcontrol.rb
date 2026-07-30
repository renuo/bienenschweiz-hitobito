# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class Qcontrol < ApplicationRecord
  include I18nEnums
  include FeeCreation
  include QcontrolNotifications

  has_one_attached :document
  validates :document, content_type: {in: ["application/pdf", "image/jpeg", "image/png"]}

  # the imker
  belongs_to :person, optional: true
  # the guy uploading the qcontrol
  belongs_to :author, class_name: "Person", optional: true
  belongs_to :inspector, class_name: "Person", optional: true
  # where the quality control has been conducted
  belongs_to :group, optional: false

  has_many :quality_control_answers, dependent: :destroy, inverse_of: :qcontrol
  accepts_nested_attributes_for :quality_control_answers, allow_destroy: true

  i18n_enum :control_state, %w[passed not_passed partially_passed], queries: true

  enum :no_control_reason, {
    no_reason: "no_reason",
    termination_of_business: "termination_of_business",
    resignation_from_certification_program: "resignation_from_certification_program",
    beekeeper_deceased: "beekeeper_deceased"
  }

  validates :control_date, presence: true

  validate do
    if person.blank? && inspector && group && inspector.inspectable_groups.exclude?(group)
      errors.add(:group_id, :not_blank_inspectable)
    end
  end

  # TODO: used for PDF, add back in when implementing that
  # get the newest one for every sektion
  # scope :latest_distinct, lambda {
  #   joins('LEFT JOIN qcontrols AS qc2
  #           ON qc2.person_id = qcontrols.person_id
  #           AND qc2.group_id = qcontrols.group_id
  #           AND qcontrols.control_date < qc2.control_date').where(qc2: {id: nil})
  # }
  #
  # # get the newest qcontrol for every distinct section, starting from the supplied year
  # scope :latest_distinct_since, lambda { |year|
  #   latest_distinct.where(["YEAR(`qcontrols`.control_date) >= ?", year])
  # }

  scope :before, ->(date) { where(arel_table[:control_date].lt(date)) }
  scope :orphan, -> { where(person: nil) }
  scope :from_yesterday, -> { where(updated_at: 1.day.ago..Time.zone.now) }
  # TODO: add back when implementing fee creating in KAS
  # scope :needs_fee_creation, lambda {
  #   fee_not_created
  #     .where.not(person: nil)
  #     .where.not(no_control_reason: %i[
  #       termination_of_business
  #       beekeeper_deceased
  #       resignation_from_certification_program
  #     ])
  # }

  before_save :set_control_state
  before_create :set_author_name
  after_create :update_beekeeper_role

  # TODO: Add back when implementing PDF
  # hacking
  # def filename
  #   self[:document]
  # end

  def name
    title || I18n.t("qcontrol_default_title")
  end

  # def personship
  #   return nil if person.blank?
  #
  #   person.personships.find_by(group_id: group.id, role: Role.siegelimker)
  # end

  # TODO: add back and adjust with API
  # def to_api
  #   {
  #     id: id,
  #     person_id: id,
  #     author_id: author_id,
  #     author_name: author.try(:human_name),
  #     group_id: group_id,
  #     title: title,
  #     document: document.to_s,
  #     control_date: control_date,
  #     file_size: file_size,
  #     content_type: content_type
  #   }
  # end

  def to_s
    "#{title} ##{id}"
  end

  # TODO: add back for PDF
  # def inspector_name
  #   @inspector_name ||= inspector&.display_name
  # end

  def first_qcontrol?
    previous_qcontrols.empty?
  end

  def previous_qcontrol
    @previous_qcontrol ||= previous_qcontrols.first
  end

  def previous_qcontrols
    return Qcontrol.none if person.blank?

    person.qcontrols.before(control_date).order(control_date: :desc)
  end

  def no_control_necessary?
    !control_performed?
  end

  def control_performed?
    no_control_reason.nil? || no_reason?
  end

  def quality_control_sections
    QualityControlSection.for_version(created_at)
  end

  def as_mobile_json
    as_json(only: %i[id author_id title control_date]).merge(
      "member_id" => person_id
    )
  end

  def as_full_mobile_json # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    extra = {
      member: {
        id: person.id,
        firstname: person.first_name,
        lastname: person.last_name
      },
      intern_structure: {
        id: group.id,
        code: group.code,
        name: group.name
      },
      quality_control_answers: quality_control_answers.map { |a|
        a.as_json(except: %i[updated_at created_at])
      }
    }
    if author
      extra[:author] = {
        id: author.id,
        firstname: author.first_name,
        lastname: author.last_name
      }
    end
    as_json(
      only: %i[id title document control_date no_control_reason
        other_reason_for_no_control business_handover_to with_voucher]
    ).merge(extra.deep_stringify_keys)
  end

  protected

  def update_beekeeper_role
    return if person.nil?

    beekeeper_role.update(end_on: (Time.zone.today + 20.days)) if not_passed?
    beekeeper_role.update(end_on: Time.zone.today) if no_control_necessary?
  end

  def beekeeper_role
    return nil if person.nil?

    person.roles.find_by(
      group_id: group.children.find_by(type: Group::Siegelimker.sti_name).id,
      type: Group::Siegelimker::Siegelimker.sti_name
    )
  end

  def set_author_name
    if author.present? && author_name.blank?
      self.author_name = author.full_name
    elsif author_name.blank? || author_name.nil?
      self.author_name = "System"
    end
  end

  def set_control_state
    return if control_state

    answer_states = quality_control_answers.map(&:fulfilled)
    self.control_state = if answer_states.include?("not_passed")
      "not_passed"
    elsif answer_states.include?("partially_passed")
      "partially_passed"
    elsif answer_states.include?("passed")
      "passed"
    end
  end
end
