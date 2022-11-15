class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.decimal :amount, null: false
      t.datetime :submitted_at, null: false
      t.belongs_to :account, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
