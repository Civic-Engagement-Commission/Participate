# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

DECIDIM_VERSION = { github: "decidim/decidim", tag: "v0.30.9" }.freeze

gem "decidim", DECIDIM_VERSION
# Optional Decidim modules (not in the meta-gem). Uncomment what you need.
# gem "decidim-ai", DECIDIM_VERSION
# gem "decidim-conferences", DECIDIM_VERSION
# gem "decidim-design", DECIDIM_VERSION
# gem "decidim-initiatives", DECIDIM_VERSION
# gem "decidim-templates", DECIDIM_VERSION

# External Decidim modules
gem "decidim-decidim_awesome", github: "decidim-ice/decidim-module-decidim_awesome", branch: "release/0.30-stable"
gem "decidim-term_customizer", github: "openpoke/decidim-module-term_customizer", branch: "release/0.30-stable"

gem "bootsnap", "~> 1.4"
gem "deface"
gem "puma", ">= 6.3.1"

gem "aws-sdk-s3"
gem "dalli"
gem "dotenv-rails", "~> 2.7"
gem "spring"

gem "net-imap", "~> 0.5.6"
gem "rails-html-sanitizer", "~> 1.6.1"

gem "omniauth-rails_csrf_protection"
gem "omniauth-saml"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "decidim-dev", DECIDIM_VERSION

  gem "brakeman", "~> 6.1"
  gem "parallel_tests", "~> 4.2"
end

group :development do
  gem "bullet"
  gem "flamegraph"
  gem "letter_opener_web", "~> 2.0"
  gem "listen", "~> 3.1"
  gem "memory_profiler"
  gem "rack-mini-profiler", require: false
  gem "stackprof"
  gem "web-console", "~> 4.2"
end

group :production do
  gem "activejob-uniqueness", require: "active_job/uniqueness/sidekiq_patch"
  gem "sidekiq", "~> 6.0"
  gem "sidekiq-scheduler", "~> 5.0"
end
