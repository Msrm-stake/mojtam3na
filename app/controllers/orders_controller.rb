class OrdersController < ApplicationController
  before_action :require_parent!
  before_action :set_order

  # Stripe sends the parent back here after paying. The payment is checked with Stripe directly,
  # so this works even if the webhook has not arrived yet.
  def paid
    if @order.status_pending? && @order.stripe_checkout_session_id.present?
      session = StripeClient.new.retrieve_checkout_session(@order.stripe_checkout_session_id)
      outcome = @order.settle!(session)
      @order.lesson.notify_participants(:booked) if outcome == :confirmed
    end

    @order.reload
    flash_type, message =
      case @order.status
      when "paid" then [:notice, t(".confirmed")]
      when "refund_pending", "refunded" then [:alert, t(".refunded_slot")]
      when "expired" then [:alert, t("orders.abandon.released")]
      else [:notice, t(".processing")]
      end
    redirect_to lessons_path, flash_type => message, status: :see_other
  rescue StripeClient::Error => e
    Rails.logger.error("Could not check order #{params[:id]}: #{e.message}")
    redirect_to lessons_path, alert: t("orders.paid.unavailable"), status: :see_other
  end

  # The parent went back from the payment page: the held time is released at once.
  def abandon
    @order.abandon!
    @order.reload

    if @order.status_paid?
      redirect_to lessons_path, notice: t("orders.paid.confirmed"), status: :see_other
    else
      redirect_to new_teacher_lesson_path(@order.lesson.teacher_profile, kind: "paid"),
                  alert: t(".released"), status: :see_other
    end
  end

  private

  def require_parent!
    redirect_to root_path, alert: t("lessons.parents_only") unless current_user.role_parent?
  end

  # A parent can only reach their own orders (anything else is a 404).
  def set_order
    @order = Order.where(parent_id: current_user.id).includes(lesson: { teacher_profile: :user }).find(params[:id])
  end
end
