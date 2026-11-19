module Admin
  class PayoutsController < BaseController
    before_action :set_payout, only: %i[show mark_paid cancel]

    def index
      @months = (1..6).map do |back|
        month = Date.current.beginning_of_month << back
        [month.strftime("%B %Y"), month.strftime("%Y-%m")]
      end

      totals = Earning.status_available.group(:teacher_profile_id).sum(:amount_cents)
      @waiting = TeacherProfile.where(id: totals.keys).includes(:user)
                               .map { |profile| [profile, totals[profile.id]] }
                               .sort_by { |_, cents| -cents }
      @payouts = Payout.includes(teacher_profile: :user).order(created_at: :desc, id: :desc).limit(100)
    end

    def show
      @profile = @payout.teacher_profile
      @earnings = @payout.earnings.includes(:lesson).order(:earned_at)
    end

    def prepare
      month = parse_month(params[:month])
      return redirect_to(admin_payouts_path, alert: t(".invalid_month"), status: :see_other) unless month

      result = Payout.prepare!(month)
      parts = [t(".prepared", count: result[:created].size)]
      if result[:missing_details].any?
        parts << t(".missing_details", names: result[:missing_details].map { |p| p.user.full_name }.to_sentence)
      end
      if result[:below_minimum].any?
        parts << t(".below_minimum", names: result[:below_minimum].map { |p| p.user.full_name }.to_sentence)
      end
      redirect_to admin_payouts_path, notice: parts.join(" "), status: :see_other
    end

    def mark_paid
      reference = params[:reference].to_s.strip

      if reference.blank?
        redirect_to admin_payout_path(@payout), alert: t(".reference_required"), status: :see_other
      elsif @payout.mark_paid!(reference)
        redirect_to admin_payout_path(@payout), notice: t(".marked"), status: :see_other
      else
        redirect_to admin_payout_path(@payout), alert: t(".not_pending"), status: :see_other
      end
    end

    def cancel
      if @payout.cancel!
        redirect_to admin_payouts_path, notice: t(".cancelled"), status: :see_other
      else
        redirect_to admin_payout_path(@payout), alert: t("admin.payouts.mark_paid.not_pending"), status: :see_other
      end
    end

    # A spreadsheet of the pending payouts, ready to be paid in one batch.
    def export
      payouts = Payout.status_pending.includes(teacher_profile: :user).order(:id)
      send_data "\uFEFF#{csv_for(payouts)}",
                filename: "mojtam3na-payouts-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8"
    end

    private

    def set_payout
      @payout = Payout.includes(teacher_profile: :user).find(params[:id])
    end

    # Only months that have already ended can be prepared.
    def parse_month(value)
      date = Date.strptime("#{value}-01", "%Y-%m-%d")
      date < Date.current.beginning_of_month ? date : nil
    rescue ArgumentError
      nil
    end

    def csv_for(payouts)
      header = %w[payout_id period teacher email method details amount_eur reference]
      rows = payouts.map do |payout|
        profile = payout.teacher_profile
        period = payout.period_start.strftime("%Y-%m")
        [payout.id, period, profile.user.full_name, profile.user.email, profile.payout_method,
         profile.payout_details, format("%.2f", payout.amount_cents / 100.0), "Mojtam3na #{period} ##{payout.id}"]
      end
      ([header] + rows).map { |row| row.map { |cell| csv_cell(cell) }.join(",") }.join("\r\n") + "\r\n"
    end

    # Quotes a value and neutralises spreadsheet formulas: a cell starting with = + - or @ could run code when opened.
    def csv_cell(value)
      text = value.to_s.tr("\r\n", "  ")
      text = "'#{text}" if text.match?(/\A[=+\-@\t]/)
      "\"#{text.gsub('"', '""')}\""
    end
  end
end
