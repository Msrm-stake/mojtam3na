class PaymentsMaintenanceJob < ApplicationJob
  queue_as :default

  # Frees unpaid held times, confirms lessons finished 24 hours ago (adding the teacher's earning),
  # and retries refunds that did not go through.
  def perform
    Lesson.release_expired_holds!
    confirmed = Lesson.complete_finished!

    refunded = 0
    Order.status_refund_pending.find_each { |order| refunded += 1 if order.refund! }

    { confirmed: confirmed, refunded: refunded }
  end
end
