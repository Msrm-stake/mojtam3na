class AddViewsCountToTeacherProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :teacher_profiles, :views_count, :integer, default: 0, null: false
  end
end
