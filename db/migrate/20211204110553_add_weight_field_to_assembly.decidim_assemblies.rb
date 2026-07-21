# frozen_string_literal: true

# This migration comes from decidim_assemblies (originally 20210204152393)
# This file has been modified by `decidim upgrade:migrations` task on 2026-07-21 08:50:52 UTC
class AddWeightFieldToAssembly < ActiveRecord::Migration[5.2]
  def change
    add_column :decidim_assemblies, :weight, :integer, null: false, default: true
  end
end
