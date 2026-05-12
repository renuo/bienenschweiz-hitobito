class Qcontrol < ApplicationRecord
  include I18nEnums
  # TODO: implmeent fee creation in kas
  # include FeeCreation
  # TODO: notification emails
  # include QcontrolNotifications

  # TODO documents
  # mount_uploader :document, AssetUploader
  attr_accessor :mass_import

  # the imker
  belongs_to :person, optional: true
  # the guy uploading the qcontrol
  belongs_to :author, class_name: 'Person', optional: true
  belongs_to :inspector, class_name: 'Person', optional: true
  # where the quality control has been conducted
  belongs_to :group

  # TODO: implement
  # has_many :quality_control_answers, dependent: :destroy, inverse_of: :qcontrol
  #
  # accepts_nested_attributes_for :quality_control_answers, allow_destroy: true

  i18n_enum :control_state, %w[passed not_passed partially_passed]
  enum :fee_creation_state, %w[fee_not_required fee_not_created fee_ok]

  enum :no_control_reason, { no_reason: 'no_reason',
                             termination_of_business: 'termination_of_business',
                             resignation_from_certification_program: 'resignation_from_certification_program',
                             beekeeper_deceased: 'beekeeper_deceased' }

  validates :control_date, presence: true

  validate do
    if person.blank? && inspector && group && inspector.inspectable_groups.exclude?(group)
      errors.add(:group_id, :not_blank_inspectable)
    end
  end

  # get the newest one for every sektion
  scope :latest_distinct, lambda {
    joins('LEFT JOIN qcontrols AS qc2
            ON qc2.person_id = qcontrols.person_id
            AND qc2.group_id = qcontrols.group_id
            AND qcontrols.control_date < qc2.control_date').where('qc2.id IS NULL')
  }

  # get the newest qcontrol for every distinct section, starting from the supplied year
  scope :latest_distinct_since, lambda { |year|
    latest_distinct.where(['YEAR(`qcontrols`.control_date) >= ?', year])
  }

  scope :before, ->(date) { where(arel_table[:control_date].lt(date)) }
  scope :orphan, -> { where(person: nil) }
  scope :from_yesterday, -> { where(updated_at: 1.day.ago..Time.zone.now) }
  scope :needs_fee_creation, lambda {
    fee_not_created
      .where.not(person: nil)
      .where.not(no_control_reason: %i[termination_of_business beekeeper_deceased resignation_from_certification_program])
  }

  before_validation :update_doc_attributes
  before_save :set_control_state
  before_create :set_author_name
  after_create :update_person_role

  # hacking
  def filename
    self[:document]
  end

  def mass_import?
    @mass_import.present? && @mass_import == true
  end

  def name
    title || I18n.t('qcontrol_default_title')
  end

  # def personship
  #   return nil if person.blank?
  #
  #   person.personships.find_by(group_id: group.id, role: Role.siegelimker)
  # end

  def to_api
    {
      id: id,
      person_id: id,
      author_id: author_id,
      author_name: author.try(:human_name),
      group_id: group_id,
      title: title,
      document: document.to_s,
      control_date: control_date,
      file_size: file_size,
      content_type: content_type
    }
  end

  def to_s
    "#{title} ##{id}"
  end

  def inspector_name
    @inspector_name ||= inspector&.display_name
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

  protected

  def update_doc_attributes
    return unless document.present? && document_changed?

    self.content_type = document.file.content_type
    self.file_size = document.file.size
  end

  def update_person_role
    return if person.nil?

    # TODO: implement/rework
    # roles.update(valid_until: (Time.zone.today + 20.days)) if not_passed? # quality control didn't pass
    # roles.update(valid_until: Time.zone.today) if no_control_necessary? # no control has been made
  end

  def set_author_name
    if author.present? && author_name.blank?
      self.author_name = author.human_name
    elsif author_name.blank? || author_name.nil?
      self.author_name = 'System'
    end
  end

  def set_control_state
    return if control_state

    answer_states = quality_control_answers.map(&:fulfilled)
    self.control_state = if answer_states.include?('not_passed')
                           'not_passed'
                         elsif answer_states.include?('partially_passed')
                           'partially_passed'
                         elsif answer_states.include?('passed')
                           'passed'
                         end
  end
end
