class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.date :date_of_birth
      t.string :username, null: false
      t.integer :role, null: false, default: 0
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
    # Usernames keep their casing but must be unique case-insensitively ("JDoe" blocks "jdoe").
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
  end
end
