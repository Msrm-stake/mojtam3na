class AddMarketplaceFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :role, :string, null: false, default: "parent"
    add_column :users, :time_zone, :string, null: false, default: "UTC"
    add_column :users, :locale, :string, null: false, default: "en"
    add_column :users, :country_code, :string, limit: 2
    add_column :users, :phone, :string
    add_column :users, :stripe_customer_id, :string
    add_column :users, :terms_accepted_at, :datetime

    add_index :users, :role
    add_index :users, :stripe_customer_id, unique: true
  end
end
