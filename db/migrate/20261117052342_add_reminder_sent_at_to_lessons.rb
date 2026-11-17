class AddReminderSentAtToLessons < ActiveRecord::Migration[7.1]
  def change
    add_column :lessons, :reminder_sent_at, :datetime
  end
end
