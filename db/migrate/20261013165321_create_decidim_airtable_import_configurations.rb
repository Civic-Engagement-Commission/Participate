# frozen_string_literal: true

class CreateDecidimAirtableImportConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_airtable_import_configurations do |t|
      t.references :decidim_organization,
                   null: false,
                   foreign_key: { to_table: :decidim_organizations },
                   index: { name: "index_decidim_airtable_import_configs_on_organization_id" }
      t.string :airtable_base_id, null: false
      t.string :airtable_table_id, null: false
      t.string :airtable_view_id
      t.jsonb :settings, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :decidim_airtable_import_configurations,
              [:decidim_organization_id, :airtable_base_id, :airtable_table_id],
              unique: true,
              name: "index_decidim_airtable_import_configs_on_org_base_table"
    add_index :decidim_airtable_import_configurations,
              [:decidim_organization_id, :active],
              name: "index_decidim_airtable_import_configs_on_org_active"
  end
end
