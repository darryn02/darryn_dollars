class CreateLines < ActiveRecord::Migration[5.0]
  def change
    create_table :lines do |t|
      t.references :contestant, foreign_key: { on_delete: :nullify}, null: true, index: true
      t.references :game, foreign_key: { on_delete: :cascade}, null: false, index: true
      t.string :description
      t.integer :kind, null: false, index: true
      t.float :value, null: false
      t.integer :odds, null: false, default: -110
      t.boolean :hidden, default: false, null: false

      t.timestamps
    end
  end
end
