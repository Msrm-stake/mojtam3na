class LessonsController < ApplicationController
  before_action :set_teacher, only: %i[new create]
  before_action :require_parent!, only: %i[new create]
  before_action :set_kind, only: %i[new create]

  def index
    scope =
      if current_user.role_teacher?
        Lesson.where(teacher_profile_id: current_user.teacher_profile&.id)
      elsif current_user.role_parent?
        Lesson.where(booked_by_id: current_user.id)
      else
        Lesson.none
      end

    scope = scope.includes(:student, :order, teacher_profile: :user)
    @upcoming = scope.upcoming.order(:starts_at)
    @history = scope.history.order(starts_at: :desc).limit(50)
  end

  def new
    return redirect_to(new_student_path, alert: t(".add_child_first")) if current_user.students.none?

    prepare_booking_page
  end

  def create
    Lesson.release_expired_holds!
    @paid ? create_paid : create_trial
  end

  def cancel
    lesson = own_lessons.find(params[:id])

    if lesson.cancellable_by?(current_user)
      lesson.cancel!(current_user)
      lesson.notify_participants(:cancelled, cancelled_by: lesson.booked_by_id == current_user.id ? "parent" : "teacher")

      order = lesson.reload.order
      message =
        if order.nil? then t(".cancelled")
        elsif order.refund! then t(".cancelled_refunded")
        else t(".cancelled_refund_pending")
        end
      redirect_to lessons_path, notice: message, status: :see_other
    else
      redirect_to lessons_path, alert: t(".too_late"), status: :see_other
    end
  end

  # The video room. Only the parent who booked and the teacher can open it, and only around the lesson time.
  def room
    @lesson = own_lessons.includes(:student, teacher_profile: :user).find(params[:id])

    unless @lesson.status_scheduled? && Time.current <= @lesson.ends_at + Lesson::JOIN_CLOSES
      return redirect_to(lessons_path, alert: t(".closed"), status: :see_other)
    end

    unless @lesson.join_open?
      return redirect_to(lessons_path, status: :see_other,
                         alert: t(".not_open", minutes: (Lesson::JOIN_OPENS / 1.minute).to_i))
    end

    @join_url = @lesson.join_url_for(current_user)
  rescue DailyClient::Error => e
    Rails.logger.error("Video room error for lesson #{params[:id]}: #{e.message}")
    redirect_to lessons_path, alert: t("lessons.room.unavailable"), status: :see_other
  end

  private

  def own_lessons
    Lesson.where(booked_by_id: current_user.id)
          .or(Lesson.where(teacher_profile_id: current_user.teacher_profile&.id))
  end

  # Only approved teachers can be booked; anything else is a 404.
  def set_teacher
    @profile = TeacherProfile.status_approved.includes(:user).find(params[:teacher_id])
  end

  def require_parent!
    redirect_to root_path, alert: t("lessons.parents_only") unless current_user.role_parent?
  end

  # "trial" (free, 30 minutes) or "paid" (60 minutes at the teacher's price, only if a euro price is set).
  def set_kind
    @paid = params[:kind] == "paid"
    return unless @paid && !helpers.lesson_payable?(@profile)

    redirect_to new_teacher_lesson_path(@profile, kind: "trial"), alert: t("lessons.new.no_price")
  end

  def lesson_params
    params.fetch(:lesson, {}).permit(:student_id, :starts_at)
  end

  def parse_time(value)
    Time.iso8601(value.to_s).utc
  rescue ArgumentError
    nil
  end

  def create_trial
    @lesson = Lesson.new(
      teacher_profile: @profile,
      booked_by: current_user,
      student: current_user.students.find_by(id: lesson_params[:student_id]),
      starts_at: parse_time(lesson_params[:starts_at]),
      trial: true,
      currency: @profile.currency
    )

    if save_lesson(@lesson)
      @lesson.notify_participants(:booked)
      redirect_to lessons_path, notice: t(".booked"), status: :see_other
    else
      prepare_booking_page
      render :new, status: :unprocessable_entity
    end
  end

  # The time is held while the parent pays on Stripe's page; the lesson is booked when the payment is confirmed.
  def create_paid
    starts = parse_time(lesson_params[:starts_at])
    @lesson = Lesson.new(
      teacher_profile: @profile,
      booked_by: current_user,
      student: current_user.students.find_by(id: lesson_params[:student_id]),
      starts_at: starts,
      ends_at: starts && starts + Lesson::PAID_MINUTES.minutes,
      trial: false,
      status: "pending_payment",
      hold_expires_at: Lesson::HOLD_MINUTES.minutes.from_now,
      price_cents: @profile.hourly_rate_cents,
      currency: "EUR"
    )

    order = nil
    saved =
      begin
        Lesson.transaction do
          @lesson.save!
          order = Order.for_lesson(@lesson)
          order.save!
        end
        true
      rescue ActiveRecord::RecordInvalid
        false
      rescue ActiveRecord::RecordNotUnique
        @lesson.errors.add(:base, :slot_taken)
        false
      end

    return start_checkout(order) if saved

    prepare_booking_page
    render :new, status: :unprocessable_entity
  end

  def start_checkout(order)
    session = StripeClient.new.create_checkout_session(
      order_id: order.id,
      lesson_id: @lesson.id,
      amount_cents: order.amount_cents,
      currency: order.currency,
      product_name: t("lessons.checkout.product", teacher: helpers.public_name(@profile.user)),
      email: current_user.email,
      success_url: paid_order_url(order),
      cancel_url: abandon_order_url(order),
      expires_at: Lesson::SESSION_MINUTES.minutes.from_now,
      locale: I18n.locale
    )
    order.update!(stripe_checkout_session_id: session["id"])
    redirect_to session["url"], allow_other_host: true, status: :see_other
  rescue StripeClient::Error => e
    Rails.logger.error("Could not start checkout for order #{order.id}: #{e.message}")
    order.abandon!
    @lesson.errors.add(:base, :payment_unavailable)
    prepare_booking_page
    render :new, status: :unprocessable_entity
  end

  def save_lesson(lesson)
    lesson.save
  rescue ActiveRecord::RecordNotUnique
    # Someone else booked this exact time a moment ago.
    lesson.errors.add(:base, :slot_taken)
    false
  end

  def prepare_booking_page
    Lesson.release_expired_holds!
    @students = current_user.students.order(:first_name)
    @zone = current_user.zone
    chosen = (params.dig(:lesson, :student_id) || params[:student_id]).to_i
    @student_id = @students.exists?(id: chosen) ? chosen : @students.first&.id
    minutes = @paid ? Lesson::PAID_MINUTES : Lesson::TRIAL_MINUTES
    @days = @profile.bookable_starts(minutes: minutes).group_by { |time| time.in_time_zone(@zone).to_date }
  end
end
