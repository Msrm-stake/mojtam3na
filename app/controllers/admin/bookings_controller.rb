module Admin
  # Who has booked what: every trial and paid lesson, plus views and bookings per teacher.
  class BookingsController < BaseController
    STATUSES = %w[all upcoming completed cancelled].freeze
    KINDS = %w[all trial paid].freeze

    def index
      @status = STATUSES.include?(params[:status]) ? params[:status] : "all"
      @kind = KINDS.include?(params[:kind]) ? params[:kind] : "all"
      @teacher_id = params[:teacher].presence

      # Lessons waiting for payment and expired payment holds are not bookings.
      booked = Lesson.where.not(status: %w[pending_payment expired])

      scope = booked.includes(:student, :booked_by, teacher_profile: :user).order(created_at: :desc)
      scope =
        case @status
        when "upcoming" then scope.upcoming
        when "completed" then scope.status_completed
        when "cancelled" then scope.status_cancelled
        else scope
        end
      scope = scope.where(trial: @kind == "trial") unless @kind == "all"
      scope = scope.where(teacher_profile_id: @teacher_id) if @teacher_id
      @lessons = scope.limit(200)

      load_teacher_activity(booked)
    end

    private

    def load_teacher_activity(booked)
      kept = booked.where.not(status: "cancelled")
      trials = kept.where(trial: true).group(:teacher_profile_id).count
      paid = kept.where(trial: false).group(:teacher_profile_id).count
      last_booking = booked.group(:teacher_profile_id).maximum(:created_at)

      @teachers = TeacherProfile.status_approved.includes(:user).to_a
      @rows = @teachers.map do |profile|
        { profile: profile, views: profile.views_count, trials: trials[profile.id].to_i,
          paid: paid[profile.id].to_i, last: last_booking[profile.id] }
      end
      @rows.sort_by! { |row| [-row[:views], -(row[:trials] + row[:paid])] }

      @total_views = @rows.sum { |row| row[:views] }
      @total_trials = @rows.sum { |row| row[:trials] }
      @total_paid = @rows.sum { |row| row[:paid] }
    end
  end
end
