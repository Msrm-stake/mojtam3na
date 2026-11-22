class AddPhotoRejectedAtToTeacherProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :teacher_profiles, :photo_rejected_at, :datetime
  end
end
