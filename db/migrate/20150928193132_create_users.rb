class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string    :username
      t.string    :first_name
      t.string    :last_name
      t.string    :password_digest
      t.string    :github_id
      t.string    :email

      t.timestamps null: false
    end
  end
end