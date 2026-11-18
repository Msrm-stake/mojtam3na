namespace :payments do
  desc "Release unpaid held lessons and retry refunds that did not go through (run every 5-10 minutes)"
  task maintenance: :environment do
    Lesson.release_expired_holds!

    refunded = 0
    Order.status_refund_pending.find_each { |order| refunded += 1 if order.refund! }
    puts "Refunds completed: #{refunded}"
  end
end
