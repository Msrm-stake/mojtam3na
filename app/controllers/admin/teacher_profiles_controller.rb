module Admin
  class TeacherProfilesController < BaseController
    before_action :set_profile, only: %i[show approve reject suspend approve_photo reject_photo remove_photo]

    def index
      @status = TeacherProfile.statuses.key?(params[:status]) ? params[:status] : "pending"
      @counts = TeacherProfile.group(:status).count
      @photos_waiting = TeacherProfile.joins(:pending_photo_attachment).includes(:user).order(:id)
      @profiles = TeacherProfile.where(status: @status).includes(:user, :qualifications).order(:created_at)
    end

    def show
      @qualifications = @profile.qualifications.with_attached_document.order(:created_at)
    end

    def approve
      missing = @profile.missing_for_approval

      if missing.empty?
        @profile.approve!(current_user)
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.approved"), status: :see_other
      else
        names = missing.map { |item| t("admin.teacher_profiles.missing.#{item}") }.to_sentence
        redirect_to admin_teacher_profile_path(@profile),
                    alert: t("admin.teacher_profiles.cannot_approve", missing: names), status: :see_other
      end
    end

    def reject
      reason = params[:rejection_reason].to_s.strip

      if reason.blank?
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.reason_required"), status: :see_other
      else
        @profile.reject!(reason)
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.rejected"), status: :see_other
      end
    end

    # An email written by the admin, sent inside the teacher email template.
    def send_message
      profile = TeacherProfile.find(params[:id])
      subject = params[:subject].to_s.gsub(/\s+/, " ").strip
      body = params[:body].to_s.strip
      if subject.blank? || body.blank?
        redirect_to admin_teacher_profile_path(profile), alert: t("admin.teacher_profiles.message_blank"), status: :see_other
      else
        TeacherMailer.with(profile: profile, subject: subject.first(150), body: body.first(5000),
                           include_missing: params[:include_missing] == "1").custom_message.deliver_later
        redirect_to admin_teacher_profile_path(profile),
                    notice: t("admin.teacher_profiles.message_sent", email: profile.user.email), status: :see_other
      end
    end

    # Welcome and reminder email to the teacher: what is still missing in the profile, in the teacher's language.
    def send_reminder
      profile = TeacherProfile.find(params[:id])
      if profile.status_suspended?
        redirect_to admin_teacher_profile_path(profile), alert: t("admin.teacher_profiles.reminder_suspended"), status: :see_other
      elsif profile.reminder_sent_at.present? && profile.reminder_sent_at > 5.minutes.ago
        redirect_to admin_teacher_profile_path(profile), alert: t("admin.teacher_profiles.reminder_too_soon"), status: :see_other
      else
        TeacherMailer.with(profile: profile).welcome_reminder.deliver_later
        profile.update_column(:reminder_sent_at, Time.current)
        redirect_to admin_teacher_profile_path(profile),
                    notice: t("admin.teacher_profiles.reminder_sent", email: profile.user.email), status: :see_other
      end
    end

    def suspend
      @profile.suspend!
      redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.suspended"), status: :see_other
    end

    def approve_photo
      if @profile.approve_photo!
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_approved"), status: :see_other
      else
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.photo_none_waiting"), status: :see_other
      end
    end

    def reject_photo
      if @profile.reject_photo!
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_rejected"), status: :see_other
      else
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.photo_none_waiting"), status: :see_other
      end
    end

    def remove_photo
      @profile.remove_photo!
      @profile.update!(photo_rejected_at: Time.current)
      redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_removed"), status: :see_other
    end

    private

    def set_profile
      @profile = TeacherProfile.find(params[:id])
    end
  end
end
