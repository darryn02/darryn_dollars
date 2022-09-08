class CreateWagers < ActiveRecord::Migration[5.0]
  def change
    create_table :wagers do |t|
      t.belongs_to :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :line, foreign_key: true, null: false, index: true
      t.datetime :placed_at
      t.decimal :amount
      t.float :vig
      t.integer :status, null: false, default: 0
      t.decimal :net

      t.timestamps
    end
  end
end
