module QcontrolNotifications
  extend ActiveSupport::Concern

  included do
    after_commit :notify_on_create, on: :create
    after_commit :notify_on_update, on: :update
  end

  def notify_on_create
    notify_on_not_passed if notify_on_not_passed?
    notify_on_not_necessary if notify_on_not_necessary?
    notify_beekeeper_and_inspector_and_secretary if notify_beekeeper_and_inspector?
    print_certificate_and_letter if print_certificate_and_letter?
  end

  def notify_on_update
    notify_beekeeper_and_inspector_and_secretary if notify_beekeeper_and_inspector?
    print_certificate_and_letter if print_certificate_and_letter?
  end

  def notify_on_not_passed
    InspectionMailer.inspection_failed_mailer(id).deliver_later
  end

  def notify_on_not_necessary
    InspectionMailer.inspection_not_necessary_mailer(id).deliver_later
  end

  def notify_beekeeper_and_inspector_and_secretary
    notify_beekeeper_and_inspector(true)
  end

  def notify_beekeeper_and_inspector(copy_to_secretary = false)
    if person.email.present?
      InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(id,
        copy_to_secretary).deliver_later
    else
      InspectionMailer.only_inspector_checklist_pdf_mailer(id, copy_to_secretary).deliver_later
    end
    # TODO: check if validations really need to be skipped
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(member_notified: true)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def notify_on_not_passed?
    from_app? && person.present? && not_passed?
  end

  def notify_on_not_necessary?
    from_app? && person.present? && no_control_necessary?
  end

  def notify_beekeeper_and_inspector?
    from_app? && person.present? && !member_notified? && control_performed?
  end

  def print_certificate_and_letter?
    person.present? && !certificate_printed && (passed? || partially_passed?)
  end

  def print_certificate_and_letter
    InspectionMailer.print_certificate_and_letter(id).deliver_later
    # TODO: check if validations really need to be skipped
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(certificate_printed: true)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
