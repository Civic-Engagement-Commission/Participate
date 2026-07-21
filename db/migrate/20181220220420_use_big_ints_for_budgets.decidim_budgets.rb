# frozen_string_literal: true

# This migration comes from decidim_budgets (originally 20181205141115)
# This file has been modified by `decidim upgrade:migrations` task on 2026-07-21 08:50:52 UTC
class UseBigIntsForBudgets < ActiveRecord::Migration[5.2]
  def change
    change_column :decidim_budgets_projects, :budget, :bigint
  end
end
