# frozen_string_literal: true

namespace :decidim_app do
  namespace :k8s do
    # This task does nothing right now, but it's a placeholder for future CI/CD pipeline tasks.
    desc "Placeholder task for future CI/CD pipeline"
    task upgrade: :environment do
      puts "Running decidim_app:k8s:upgrade"
    end
  end
end
