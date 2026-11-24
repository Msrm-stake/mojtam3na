class AddSubmittedAtToTeacherProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :teacher_profiles, :submitted_at, :datetime
    reversible do |dir|
      # Profiles that were already reviewed count as submitted.
      dir.up { execute "UPDATE teacher_profiles SET submitted_at = created_at WHERE status <> 'pending'" }
    end
  end
end
