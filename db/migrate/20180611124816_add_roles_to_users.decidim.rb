# frozen_string_literal: true

# This migration comes from decidim (originally 20170727125445)
# This file has been modified by `decidim upgrade:migrations` task on 2026-07-21 08:50:52 UTC
class AddRolesToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_users, :roles, :string, array: true, default: []
  end
end
