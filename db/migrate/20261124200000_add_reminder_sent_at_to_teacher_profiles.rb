class AddReminderSentAtToTeacherProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :teacher_profiles, :reminder_sent_at, :datetime
  end
end
