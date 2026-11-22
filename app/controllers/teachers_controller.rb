class TeachersController < ApplicationController
  # Parents can browse teachers before creating an account.
  skip_before_action :authenticate_user!

  SORTS = %w[newest price_asc price_desc].freeze

  def index
    @subjects = Subject.order(:id)
    @languages = Language.alphabetical
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "newest"

    scope = TeacherProfile.status_approved.includes(:user, :languages, :subjects).with_attached_photo
    if params[:subject].present?
      scope = scope.where(id: TeacherSubject.where(subject_id: params[:subject]).select(:teacher_profile_id))
    end
    if params[:language].present?
      scope = scope.where(id: TeacherLanguage.where(language_id: params[:language]).select(:teacher_profile_id))
    end

    @profiles =
      case @sort
      when "price_asc" then scope.order(:hourly_rate_cents, :id)
      when "price_desc" then scope.order(hourly_rate_cents: :desc, id: :asc)
      else scope.order(approved_at: :desc, id: :desc)
      end.limit(48)
  end

  def show
    # Only approved profiles are public: anything else is a 404.
    @profile = TeacherProfile.status_approved.includes(:user, :languages, :subjects).with_attached_photo.find(params[:id])
    @qualifications = @profile.qualifications.status_verified.order(:year_obtained, :id)
  end
end
