class CreateScrapeRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :scrape_runs do |t|
      t.string :sport, null: false
      t.string :scope
      t.datetime :ran_at, null: false
      t.string :outcome, null: false
      t.integer :lines_created, default: 0, null: false
      t.integer :lines_activated, default: 0, null: false
      t.integer :lines_deactivated, default: 0, null: false
      t.integer :http_status
      t.string :content_type
      t.text :detail

      t.timestamps
    end

    add_index :scrape_runs, [:sport, :ran_at]
    add_index :scrape_runs, :ran_at
  end
end
