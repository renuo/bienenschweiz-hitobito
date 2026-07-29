# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

# Must be a plain Ruby module (not ActiveSupport::Concern) so that self.prepended
# fires reliably, mirroring Bienenschweiz::ClearsArrayColumnValidators. Core's
# required-answer presence validator doesn't account for question relevance, so
# it is removed and re-added with the extra condition instead of just adding a
# second, independent validator alongside it.
module Bienenschweiz::Event::Answer
  def self.prepended(base)
    super
    remove_core_presence_validator(base)
    add_relevance_aware_presence_validator(base)
  end

  def self.remove_core_presence_validator(base)
    base._validators[:answer].reject! { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
    base._validate_callbacks.select { |cb| presence_validator_callback?(cb) }
      .each { |cb| base._validate_callbacks.delete(cb) }
  end

  def self.presence_validator_callback?(callback)
    callback.filter.is_a?(ActiveModel::Validations::PresenceValidator) &&
      callback.filter.attributes.include?(:answer)
  end

  def self.add_relevance_aware_presence_validator(base)
    base.validates :answer, presence: {if: :answer_required?}
  end

  def answer_required?
    question&.required? && participation.enforce_required_answers &&
      question.relevant_for?(participation)
  end
end
