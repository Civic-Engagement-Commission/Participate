# frozen_string_literal: true

require "spec_helper"

# Lock upstream files our overrides depend on. If any of these checksums change
# after `bundle update decidim*`, the override must be re-audited against the
# new upstream version before the upgrade is merged.
checksums = [
  {
    package: "decidim-core",
    files: {
      "/app/views/decidim/devise/shared/_omniauth_buttons.html.erb" => "688a13e36af349a91e37b04c6caaa3a9",
      "/app/views/layouts/decidim/header/_main.html.erb" => "a090eeca739613446d2eab8f4de513b1",
      "/app/views/decidim/devise/sessions/new.html.erb" => "da0d18178c8dcead2774956e989527c5",
      "/app/cells/decidim/data_consent/category.erb" => "2ae94e0a35b44657f261ac90e955b305",
      "/app/controllers/decidim/devise/omniauth_registrations_controller.rb" => "cafb652eb07048c88a4c233e4fce77d5"
    }
  },
  {
    package: "decidim-proposals",
    files: {
      "/lib/decidim/proposals/import/proposal_creator.rb" => "dbf50796e281271bbd1e830a10e57c80"
    }
  }
]

describe "Overriden files", type: :view do
  checksums.each do |item|
    spec = Gem::Specification.find_by_name(item[:package])
    item[:files].each do |file, signature|
      it "#{spec.gem_dir}#{file} matches checksum" do
        expect(md5("#{spec.gem_dir}#{file}")).to eq(signature)
      end
    end
  end

  private

  def md5(file)
    Digest::MD5.hexdigest(File.read(file))
  end
end
