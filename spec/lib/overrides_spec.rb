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
      "/app/views/layouts/decidim/header/_main.html.erb" => "2808459045fd14b7f8d689fbbd6dfa4e",
      "/app/views/decidim/devise/sessions/new.html.erb" => "da0d18178c8dcead2774956e989527c5",
      "/app/controllers/decidim/devise/omniauth_registrations_controller.rb" => "d123849baa422016934a6adb9f05a10a",
      "/app/views/layouts/decidim/_head_extra.html.erb" => "25642b423f3b3a1ac9c69bf558a6b791",
      "/app/helpers/decidim/meta_tags_helper.rb" => "ba41f00208d4eb668e320980a9b63467",
      "/app/helpers/decidim/taxonomies_helper.rb" => "4e7dd3e8f0e81e18393007f497a21ea8"
    }
  },
  {
    package: "decidim-admin",
    files: {
      "/app/helpers/decidim/admin/settings_helper.rb" => "df0d80bd60b42be822b9948909a01f53"
    }
  },
  {
    package: "decidim-participatory_processes",
    files: {
      "/app/controllers/decidim/participatory_processes/participatory_processes_controller.rb" => "ecf293796b0ce5c2b84041c188e289e4"
    }
  },
  {
    package: "decidim-proposals",
    files: {
      "/lib/decidim/proposals/import/proposal_creator.rb" => "02c7615192d42d6da3ed94d8c36754cc",
      "/app/views/decidim/proposals/admin/proposals/_form.html.erb" => "6317b6d745184c2213620120f3ff1b88",
      "/app/views/decidim/proposals/proposals/_edit_form_fields.html.erb" => "93a1717d59b8a6c74c27654790d42ae0"
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
