class AddVideoRoomToLessons < ActiveRecord::Migration[7.1]
  def change
    add_column :lessons, :video_room_name, :string
    add_column :lessons, :video_room_url, :string
    add_index :lessons, :video_room_name, unique: true
  end
end
