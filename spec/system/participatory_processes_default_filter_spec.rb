# frozen_string_literal: true

require "spec_helper"

describe "Participatory processes default date filter" do
  let(:organization) { create(:organization) }
  let!(:active_process) { create(:participatory_process, title: { en: "Started today" }, start_date: Date.current, organization:) }
  let!(:active_process2) { create(:participatory_process, title: { en: "Started 1 day ago" }, start_date: 1.day.ago, organization:) }
  let!(:past_process) { create(:participatory_process, :past, title: { en: "Ended 1 week ago" }, organization:) }
  let!(:past_process2) { create(:participatory_process, :past, title: { en: "Ended 1 month ago" }, end_date: 1.month.ago, organization:) }
  let!(:upcoming_process) { create(:participatory_process, :upcoming, title: { en: "Starts 1 week from now" }, organization:) }
  let!(:upcoming_process2) { create(:participatory_process, :upcoming, title: { en: "Starts 1 year from now" }, start_date: 1.year.from_now, organization:) }
  let(:titles) { page.all(".card__grid-text h3").map(&:text) }

  before do
    switch_to_host(organization.host)
    visit decidim_participatory_processes.participatory_processes_path
  end

  it "selects 'all' in the date filter" do
    within "#panel-dropdown-menu-date" do
      expect(page).to have_checked_field("All", visible: :all)
    end
  end

  it "lists every published process without touching the filter" do
    within "#processes-grid h2" do
      expect(page).to have_content("6 processes")
    end

    within "#processes-grid" do
      expect(page).to have_css("a.card__grid", count: 6)
      expect(titles).to contain_exactly(
        "Started today",
        "Started 1 day ago",
        "Ended 1 week ago",
        "Ended 1 month ago",
        "Starts 1 week from now",
        "Starts 1 year from now"
      )
    end
  end

  it "still filters when another date is chosen" do
    within "#panel-dropdown-menu-date" do
      click_filter_item "Active"
    end

    within "#processes-grid h2" do
      expect(page).to have_content("2 active processes")
    end

    within "#processes-grid" do
      expect(titles).to contain_exactly("Started today", "Started 1 day ago")
    end
  end
end
