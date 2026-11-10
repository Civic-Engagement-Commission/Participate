# frozen_string_literal: true

class CreateDecidimAirtableImportRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_airtable_import_runs do |t|
      t.references :decidim_airtable_import_configuration,
                   null: false,
                   foreign_key: { to_table: :decidim_airtable_import_configurations },
                   index: { name: "index_airtable_import_runs_on_configuration_id" }
      t.references :decidim_user,
                   foreign_key: { to_table: :decidim_users },
                   index: { name: "index_airtable_import_runs_on_requested_by_id" }
      t.string :status, null: false, default: "pending"
      t.string :job_id
      t.integer :fetched_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :error_details, null: false, default: []
      t.text :last_error
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :decidim_airtable_import_runs,
              [:decidim_airtable_import_configuration_id, :created_at],
              name: "index_airtable_import_runs_on_configuration_and_created_at"
  end
end
