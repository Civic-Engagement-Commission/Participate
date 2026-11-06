# frozen_string_literal: true

class CreateDecidimAirtableImportRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_airtable_import_records do |t|
      t.references :decidim_airtable_import_configuration,
                   null: false,
                   foreign_key: { to_table: :decidim_airtable_import_configurations },
                   index: { name: "index_airtable_import_records_on_configuration_id" }
      t.references :decidim_organization,
                   null: false,
                   foreign_key: { to_table: :decidim_organizations },
                   index: { name: "index_airtable_import_records_on_organization_id" }
      t.bigint :decidim_proposal_id
      t.string :airtable_record_id, null: false
      t.string :external_identifier
      t.string :status, null: false, default: "pending"
      t.string :row_checksum
      t.datetime :last_synced_at
      t.text :last_error
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_foreign_key :decidim_airtable_import_records,
                    :decidim_proposals_proposals,
                    column: :decidim_proposal_id

    add_index :decidim_airtable_import_records,
              [:decidim_airtable_import_configuration_id, :airtable_record_id],
              unique: true,
              name: "index_airtable_import_records_on_config_and_airtable_record"

    add_index :decidim_airtable_import_records,
              [:decidim_airtable_import_configuration_id, :external_identifier],
              unique: true,
              where: "external_identifier IS NOT NULL",
              name: "index_airtable_import_records_on_config_and_external_identifier"

    add_index :decidim_airtable_import_records,
              :decidim_proposal_id,
              name: "index_airtable_import_records_on_proposal_id"
  end
end
