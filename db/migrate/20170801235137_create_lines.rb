class CreateLines < ActiveRecord::Migration[5.0]
  def change
    create_table :lines do |t|
      t.belongs_to :contest, foreign_key: true, null: false, index: true
      t.string :type, null: false, index: true
      t.float :value, null: false
      t.integer :odds, null: false, default: -110
      t.boolean :hidden, default: false, null: false

      t.timestamps
    end
  end
end
