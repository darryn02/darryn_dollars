class CreateWagers < ActiveRecord::Migration[5.0]
  def change
    create_table :wagers do |t|
      t.references :betting_slip, foreign_key: true, null: false, index: true
      t.references :line, foreign_key: true, null: false, index: true
      t.datetime :placed_at
      t.decimal :amount_wagered
      t.float :vig
      t.integer :result
      t.decimal :net

      t.timestamps
    end
  end
end
