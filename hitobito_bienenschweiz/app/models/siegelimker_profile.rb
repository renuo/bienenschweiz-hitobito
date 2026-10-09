# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Information about a Siegelimker which is published on the BienenSchweiz website.
class SiegelimkerProfile < ApplicationRecord
  include I18nEnums

  AVAILABILITIES = %w[not_offered available unavailable].freeze
  PRODUCTS = %i[honey propolis pollen queens wax].freeze
  BEE_LOCATIONS = (1..5).map { |i| :"bee_location_#{i}" }.freeze
  MAX_SALES_POINTS = 5
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png].freeze

  belongs_to :person
  has_many :sales_points, -> { order(:id) }, class_name: "SiegelimkerSalesPoint",
    dependent: :destroy, inverse_of: :siegelimker_profile

  has_one_attached :background_image

  accepts_nested_attributes_for :sales_points, allow_destroy: true,
    reject_if: ->(attrs) { attrs.except("id", "_destroy").values.all?(&:blank?) }

  PRODUCTS.each do |product|
    i18n_enum :"#{product}_availability", AVAILABILITIES,
      i18n_prefix: "activerecord.attributes.siegelimker_profile.availabilities",
      scopes: false, queries: false
  end

  validates_by_schema
  validates :siegelimker_since, numericality: {
    only_integer: true, greater_than_or_equal_to: 1900,
    less_than_or_equal_to: ->(_) { Time.zone.today.year }
  }, allow_nil: true
  validates :website,
    format: {with: /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/},
    allow_blank: true
  validates :lat, numericality: {in: -90..90}, allow_nil: true
  validates :lng, numericality: {in: -180..180}, allow_nil: true
  validates :background_image, content_type: IMAGE_CONTENT_TYPES,
    dimension: {width: {max: 8_000}, height: {max: 8_000}}
  validate :assert_sales_points_limit
  validate :assert_complete_coordinates

  # Coordinates entered by the user are kept, cleared ones are looked up again.
  before_validation :detect_manual_coordinates,
    if: -> { will_save_change_to_lat? || will_save_change_to_lng? }
  before_save :geocode, unless: :manual_coordinates?
  after_commit :purge_background_image, on: %i[create update], if: :remove_background_image

  def to_s
    title.presence || person.to_s
  end

  def remove_background_image
    @remove_background_image || false
  end

  def remove_background_image=(value)
    @remove_background_image = ActiveRecord::Type::Boolean.new.cast(value)
  end

  def purge_background_image
    background_image.purge_later if background_image.persisted?
  end

  def bee_locations
    BEE_LOCATIONS.map { |attr| self[attr] }.compact_blank
  end

  def coordinates?
    lat.present? && lng.present?
  end

  # The address of the first sales point, or the person's address if no sales point has one.
  def geocoding_address
    sales_point = sales_points.reject(&:marked_for_destruction?).find { |sp| sp.address.present? }
    sales_point&.address || person_address
  end

  # Looks up the coordinates if the geocoding address changed since the last lookup.
  def geocode
    address = geocoding_address
    return if address.blank? || (address == geocoded_address && coordinates?)

    self.lat, self.lng = GeoAdminGeocoder.new.lookup(address)
    self.geocoded_address = address
  rescue GeoAdminGeocoder::Error => e
    Rails.logger.warn("Geocoding of siegelimker profile #{id} failed: #{e.message}")
  end

  # Sets coordinates which were determined elsewhere for the current geocoding address,
  # so they are kept until that address changes.
  def assign_geocoded_coordinates(lat, lng)
    self.lat = lat
    self.lng = lng
    self.geocoded_address = geocoding_address
    @coordinates_geocoded = true
  end

  private

  def person_address
    street = [person.street, person.housenumber].compact_blank.join(" ")
    town = [person.zip_code, person.town].compact_blank.join(" ")
    [street, town].compact_blank.join(", ").presence
  end

  def detect_manual_coordinates
    self.manual_coordinates = coordinates? unless @coordinates_geocoded
  end

  def assert_complete_coordinates
    if lat.present? != lng.present?
      errors.add(lat.present? ? :lng : :lat, :blank)
    end
  end

  def assert_sales_points_limit
    if sales_points.count { |element| !element.marked_for_destruction? } > MAX_SALES_POINTS
      errors.add(:sales_points, :too_many, count: MAX_SALES_POINTS)
    end
  end
end
