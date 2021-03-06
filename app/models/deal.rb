class Deal < ApplicationRecord
  # Constants
  MAXIMUM_ALLOWED_IMAGE_SIZE = 100000
  MINIMUM_IMAGE_COUNT = 1
  MINIMUM_LOCATION_COUNT = 1
  # accessors
  attr_accessor :published_from_collection
  # Assciations
  has_many :deals_locations, dependent: :destroy
  has_many :locations, through: :deals_locations
  has_many :line_items
  has_many :orders, through: :line_items
  belongs_to :category
  belongs_to :collection, optional: true
  has_many_attached :images
  accepts_nested_attributes_for :images_attachments, allow_destroy: true
  # Callbacks
  after_create :validate_start_at
  before_update :purge_images
  # Validations
  validates :title, presence: true
  validates :title, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :minimum_purchases_required, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :maximum_purchases_allowed, numericality: { greater_than: :minimum_purchases_required }, allow_nil: true
  validates :start_at, :expire_at, :price, presence: true
  validates :price, numericality: { greater_than_or_equal_to: MINIMUM_ALLOWED_PRICE }, allow_nil: true
  validates :price, numericality: { less_than_or_equal_to: MAXIMUM_ALLOWED_PRICE }, allow_nil: true
  validates :maximum_purchases_per_customer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :maximum_purchases_per_customer, numericality: { less_than_or_equal_to: :maximum_purchases_allowed }, allow_nil: true
  validates :start_at, date_range: { greater_than: :current_time }, on: :create
  validates :start_at, date_range: { greater_than: :created_at }, on: :update
  validates :expire_at, date_range: { greater_than: :start_at }
  validate :images_size_constraint
  validate :check_publishability, on: :update, if: :published_at_changed?
  validate :check_if_live_or_expired, on: :update, unless: :published_at_changed?
  #scopes
  scope :available_for_collection, ->(collection) { where(collection_id: nil, published_at: nil).or(Deal.where(collection_id: collection.id)) }
  scope :published, -> { where.not(published_at: nil) }
  scope :filter, ->(filters) { where(filters) }
  scope :live, -> { where('expire_at > ?', Time.current) }
  scope :search, ->(search) { joins(locations: :address).where(Address.arel_table[:city].matches("#{search}%").or(Deal.arel_table[:title].matches("#{search}%")).to_sql) if search.present? }
  scope :expired_today, -> { where(expire_at: (Time.current - 1.day)..Time.current) }

  def publish
    update(published_at: Time.current)
  end

  def minimum_criteria_met?
    quantity_sold >= minimum_purchases_required
  end

  def generate_coupons
    line_items.each do |line_item|
      line_item.generate_coupons
      line_item.order.current_user = User.sys_admin
      line_item.order.deliver!
    end
  end

  def cancel_orders
    orders.each do |order|
      order.current_user = User.sys_admin
      order.cancel!
    end
  end

  def unpublish
    update(published_at: nil)
  end

  def published?
    published_at.present?
  end

  def expired?
    expire_at < Time.current
  end

  def quantity_sold
    orders.joins(:line_items).with_completed_state.sum('line_items.quantity')
  end

  def quantity_left
    maximum_purchases_allowed - quantity_sold
  end

  def percentage_sold
    (quantity_sold / maximum_purchases_allowed.to_f * 100).to_i
  end

  private def validate_start_at
    if start_at < created_at
      errors.add(:start_at, 'cannot be less than the current time')
      raise ActiveRecord::Rollback
    end
  end

  private def purge_images
    images_attachments.each do |image_attachment|
      if image_attachment.marked_for_destruction?
        image_attachment.blob.purge_later
      end
    end
  end

  private def images_size_constraint
    images.each do |image|
      if image.blob && image.blob.byte_size > MAXIMUM_ALLOWED_IMAGE_SIZE
        image.purge
        image.blob.purge
        errors.add(:images, 'only 100 kb image allowed')
      end
    end
  end

  private def check_publishability
    check_location_presence
    check_image_presence
    check_collection_presence
  end

  private def check_location_presence
    if locations.count < MINIMUM_LOCATION_COUNT
      errors.add(:base, I18n.t('location_not_present'))
    end
  end

  private def check_collection_presence
    if collection_id.present? && published_from_collection.nil?
      errors.add(:base, I18n.t('collection_present'))
    end
  end

  private def check_image_presence
    if images.count < MINIMUM_IMAGE_COUNT
      errors.add(:base, I18n.t('image_not_present'))
    end
  end

  private def check_if_live_or_expired
    if published_at.present? || expire_at < Time.current
      errors.add(:base, I18n.t('live_or_expired_deal'))
    end
  end

end
