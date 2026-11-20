# Closes an account: personal data is erased, accounting records (orders, earnings, payouts) are kept without a name.
class AccountDeletion
  class Blocked < StandardError
    attr_reader :reasons

    def initialize(reasons)
      @reasons = reasons
      super("Account cannot be deleted: #{reasons.join(', ')}")
    end
  end

  def initialize(user)
    @user = user
  end

  # What still prevents the deletion (an empty list means it can go ahead).
  def blockers
    Lesson.release_expired_holds!
    reasons = []
    reasons << :admin_account if @user.role_admin?
    reasons << :upcoming_lessons if own_lessons.status_scheduled.exists?
    reasons << :payments_in_progress if Order.where(parent_id: @user.id, status: %w[pending refund_pending]).exists?
    reasons << :unpaid_earnings if unpaid_earnings?
    reasons
  end

  def call!(now: Time.current)
    reasons = blockers
    raise Blocked.new(reasons) if reasons.any?

    User.transaction do
      @user.lock!
      anonymize_children
      remove_teacher_content
      anonymize_user(now)
    end
  end

  private

  def own_lessons
    Lesson.where(booked_by_id: @user.id).or(Lesson.where(teacher_profile_id: @user.teacher_profile&.id))
  end

  def unpaid_earnings?
    profile = @user.teacher_profile
    profile.present? && profile.earnings.where(status: %w[available in_payout]).exists?
  end

  # A child with a payment is kept, without a name (only the birth year stays). Others are removed.
  def anonymize_children
    @user.students.find_each do |student|
      if paid_records?(student)
        student.update_columns(first_name: "Deleted child", birth_date: Date.new(student.birth_date.year, 1, 1),
                               gender: nil, native_language_id: nil, learning_goals: nil, updated_at: Time.current)
      else
        student.destroy!
      end
    end
  end

  def paid_records?(student)
    Order.where(lesson_id: student.lessons.select(:id)).where.not(status: "expired").exists?
  end

  def remove_teacher_content
    profile = @user.teacher_profile
    return unless profile

    profile.qualifications.each do |qualification|
      qualification.document.purge if qualification.document.attached?
      qualification.destroy!
    end
    profile.teacher_languages.destroy_all
    profile.teacher_subjects.destroy_all
    profile.availability_slots.destroy_all
    profile.update_columns(status: "suspended", headline: nil, bio: nil, gender: nil, years_experience: nil,
                           intro_video_url: nil, min_age: nil, max_age: nil, hourly_rate_cents: 0,
                           payout_method: nil, payout_details: nil, payout_details_updated_at: nil,
                           rejection_reason: nil, updated_at: Time.current)
  end

  def anonymize_user(now)
    @user.consents.update_all(ip_address: nil)
    @user.update_columns(
      email: "deleted-#{@user.id}@deleted.invalid",
      first_name: "Deleted",
      last_name: "user",
      phone: nil,
      country_code: nil,
      stripe_customer_id: nil,
      encrypted_password: User.new(password: SecureRandom.hex(32)).encrypted_password,
      reset_password_token: nil,
      reset_password_sent_at: nil,
      remember_created_at: nil,
      deleted_at: now,
      updated_at: now
    )
  end
end
