namespace :payments do
  desc "Confirm finished lessons, release unpaid held lessons, retry refunds (run every 5-10 minutes)"
  task maintenance: :environment do
    Lesson.release_expired_holds!
    confirmed = Lesson.complete_finished!

    refunded = 0
    Order.status_refund_pending.find_each { |order| refunded += 1 if order.refund! }
    puts "Lessons confirmed: #{confirmed}. Refunds completed: #{refunded}"
  end
end
