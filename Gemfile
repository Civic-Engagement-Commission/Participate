# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

DECIDIM_VERSION = { github: "decidim/decidim", branch: "release/0.31-stable" }.freeze

gem "decidim", DECIDIM_VERSION
# Optional Decidim modules (not in the meta-gem). Uncomment what you need.
# gem "decidim-ai", DECIDIM_VERSION
# gem "decidim-conferences", DECIDIM_VERSION
# gem "decidim-design", DECIDIM_VERSION
# gem "decidim-initiatives", DECIDIM_VERSION
gem "decidim-templates", DECIDIM_VERSION

# External Decidim modules
gem "decidim-decidim_awesome", github: "decidim-ice/decidim-module-decidim_awesome", branch: "main"
gem "decidim-term_customizer", github: "openpoke/decidim-module-term_customizer", branch: "main"

gem "decidim-impex", github: "openpoke/decidim-module-impex", branch: "main"

gem "bootsnap", "~> 1.4"
gem "deface"
gem "puma", ">= 6.3.1"

gem "aws-sdk-s3"
gem "dalli"
gem "dotenv-rails", "~> 2.7"

gem "omniauth-rails_csrf_protection"
gem "omniauth-saml"
gem "rails_semantic_logger"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "decidim-dev", DECIDIM_VERSION

  gem "brakeman", "~> 6.1"
  gem "parallel_tests", "~> 4.2"
end

group :development do
  gem "bullet"
  gem "flamegraph"
  gem "letter_opener_web"
  gem "memory_profiler"
  gem "rack-mini-profiler", require: false
  gem "stackprof"
  gem "web-console"
end

group :production do
  gem "sidekiq"
  gem "sidekiq-cron"
end
