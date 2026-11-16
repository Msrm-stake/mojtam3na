class Qualification < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[application/pdf image/jpeg image/png].freeze
  MAX_DOCUMENT_SIZE = 5.megabytes

  belongs_to :teacher_profile
  belongs_to :verified_by, class_name: "User", optional: true

  has_one_attached :document

  enum :kind, { ijazah: "ijazah", degree: "degree", certificate: "certificate", other: "other" },
       prefix: true, validate: true
  enum :status, { pending: "pending", verified: "verified", rejected: "rejected" }, prefix: true

  validates :title, presence: true
  validates :document, presence: true, on: :create
  validates :year_obtained,
            numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true
  validate :document_must_be_acceptable

  def verify!(admin)
    update!(status: "verified", verified_by: admin, verified_at: Time.current, admin_notes: nil)
  end

  def reject!(admin, notes)
    update!(status: "rejected", verified_by: admin, verified_at: Time.current, admin_notes: notes)
  end

  private

  def document_must_be_acceptable
    return unless document.attached?

    errors.add(:document, :invalid_type) unless ALLOWED_CONTENT_TYPES.include?(document.content_type)
    errors.add(:document, :too_large) if document.blob.byte_size > MAX_DOCUMENT_SIZE
  end
end
