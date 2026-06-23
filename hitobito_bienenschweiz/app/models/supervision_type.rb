class SupervisionType < ApplicationRecord
  has_many :supervisions, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true

  def to_s
    name
  end
end
