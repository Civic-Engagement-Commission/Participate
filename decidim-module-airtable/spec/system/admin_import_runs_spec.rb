# frozen_string_literal: true

require_relative "../rails_helper"

describe "Admin Airtable import runs" do
  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :confirmed, :admin, organization:) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: { "airtable_table_name" => "Ideas" },
      active: true
    )
  end
  let!(:import_run) do
    import_configuration.import_runs.create!(
      requested_by: admin,
      status: :completed_with_errors,
      fetched_count: 3,
      created_count: 1,
      updated_count: 1,
      failed_count: 1,
      error_details: [
        {
          "airtable_record_id" => "rec-failed",
          "proposal_title" => "Broken park proposal",
          "proposal_reference" => "PR-27",
          "error" => "Invalid title"
        }
      ]
    )
  end

  before do
    switch_to_host(organization.host)
    login_as admin, scope: :user
  end

  it "shows counts and row errors on the run page" do
    visit "/admin/airtable/imports/#{import_configuration.id}/runs/#{import_run.id}"

    expect(page).to have_content("Completed with errors")
    expect(page).to have_content("Rows fetched")
    expect(page).to have_content("3")
    expect(page).to have_content("rec-failed")
    expect(page).to have_content("Broken park proposal")
    expect(page).to have_content("PR-27")
    expect(page).to have_content("Invalid title")
  end

  it "shows the latest run status on the imports index" do
    visit "/admin/airtable/imports"

    expect(page).to have_link("Completed with errors", href: "/admin/airtable/imports/#{import_configuration.id}/runs/#{import_run.id}")
  end
end
