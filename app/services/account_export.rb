# Everything we hold about one person, as a plain hash for the "Download my data" file.
class AccountExport
  def initialize(user)
    @user = user
  end

  def to_h
    data = {
      generated_at: iso(Time.current),
      account: account,
      consents: consents,
      children: children,
      lessons: lessons,
      orders: orders
    }
    data[:teacher] = teacher if @user.teacher_profile
    data
  end

  private

  def iso(time)
    time&.iso8601
  end

  def euros(cents)
    format("%.2f", cents.to_i / 100.0)
  end

  def public_name(user)
    initial = user.last_name.to_s.strip[0]
    [user.first_name, initial && "#{initial}."].compact_blank.join(" ")
  end

  def account
    {
      id: @user.id, email: @user.email, first_name: @user.first_name, last_name: @user.last_name,
      role: @user.role, language: @user.locale, time_zone: @user.time_zone, country_code: @user.country_code,
      phone: @user.phone, created_at: iso(@user.created_at), terms_accepted_at: iso(@user.terms_accepted_at)
    }
  end

  def consents
    @user.consents.order(:accepted_at).map do |consent|
      { kind: consent.kind, accepted_at: iso(consent.accepted_at), revoked_at: iso(consent.revoked_at),
        ip_address: consent.ip_address }
    end
  end

  def children
    @user.students.includes(:native_language).order(:created_at).map do |student|
      { first_name: student.first_name, birth_date: student.birth_date.iso8601, gender: student.gender,
        native_language: student.native_language&.name, arabic_level: student.arabic_level,
        quran_level: student.quran_level, learning_goals: student.learning_goals, created_at: iso(student.created_at) }
    end
  end

  def lessons
    scope =
      if @user.role_teacher?
        Lesson.where(teacher_profile_id: @user.teacher_profile&.id)
      else
        Lesson.where(booked_by_id: @user.id)
      end

    scope.includes(:student, teacher_profile: :user).order(:starts_at).map do |lesson|
      row = { id: lesson.id, starts_at: iso(lesson.starts_at), ends_at: iso(lesson.ends_at), status: lesson.status,
              trial: lesson.trial, price_eur: euros(lesson.price_cents) }
      if @user.role_teacher?
        row[:child] = { first_name: lesson.student.first_name, age: lesson.student.age }
      else
        row[:teacher] = public_name(lesson.teacher_profile.user)
        row[:child] = lesson.student.first_name
      end
      row
    end
  end

  def orders
    Order.where(parent_id: @user.id).order(:id).map do |order|
      { id: order.id, lesson_id: order.lesson_id, amount_eur: euros(order.amount_cents), currency: order.currency,
        status: order.status, paid_at: iso(order.paid_at), refunded_at: iso(order.refunded_at) }
    end
  end

  def teacher
    profile = @user.teacher_profile
    {
      status: profile.status,
      headline: profile.headline,
      bio: profile.bio,
      gender: profile.gender,
      years_experience: profile.years_experience,
      intro_video_url: profile.intro_video_url,
      hourly_rate_eur: euros(profile.hourly_rate_cents),
      student_ages: [profile.min_age, profile.max_age],
      rejection_reason: profile.rejection_reason,
      languages: profile.languages.map(&:name),
      subjects: profile.subjects.map(&:name),
      qualifications: profile.qualifications.order(:id).map do |q|
        { kind: q.kind, title: q.title, institution: q.institution, year_obtained: q.year_obtained,
          status: q.status, reviewer_notes: q.admin_notes, document_uploaded: q.document.attached? }
      end,
      weekly_availability: profile.availability_slots.order(:weekday, :start_minute).map do |slot|
        { weekday: slot.weekday, from_minute: slot.start_minute, to_minute: slot.end_minute }
      end,
      payout_method: profile.payout_method,
      payout_details: profile.payout_details,
      earnings: profile.earnings.order(:id).map do |e|
        { lesson_id: e.lesson_id, amount_eur: euros(e.amount_cents), status: e.status, earned_at: iso(e.earned_at) }
      end,
      payouts: profile.payouts.order(:id).map do |p|
        { period: p.period_start.strftime("%Y-%m"), amount_eur: euros(p.amount_cents), status: p.status,
          reference: p.reference, paid_at: iso(p.paid_at) }
      end
    }
  end
end
