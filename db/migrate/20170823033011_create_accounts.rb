class CreateAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :accounts do |t|
      t.belongs_to :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, index: true
      t.string :nickname, index: true
      t.decimal :credit_limit, null: false

      t.timestamps
    end
  end
end
