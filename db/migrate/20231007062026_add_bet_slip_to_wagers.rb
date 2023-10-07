class AddBetSlipToWagers < ActiveRecord::Migration[7.0]
  def change
    add_reference :wagers, :bet_slip, null: false, foreign_key: { on_delete: :cascade }
  end
end
