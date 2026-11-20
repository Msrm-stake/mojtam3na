namespace :lessons do
  desc "Email parent and teacher about lessons starting within the next hour (also runs on a schedule in production)"
  task send_reminders: :environment do
    puts "Sent reminders for #{LessonRemindersJob.perform_now} lesson(s)"
  end
end
