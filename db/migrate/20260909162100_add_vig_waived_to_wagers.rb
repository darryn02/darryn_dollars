class AddVigWaivedToWagers < ActiveRecord::Migration[7.0]
  def change
    add_column :wagers, :vig_waived, :boolean, default: false, null: false
  end
end
