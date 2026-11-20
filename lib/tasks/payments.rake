namespace :payments do
  desc "Confirm finished lessons, release unpaid held lessons, retry refunds (also runs on a schedule in production)"
  task maintenance: :environment do
    puts "Payments maintenance: #{PaymentsMaintenanceJob.perform_now.inspect}"
  end
end
