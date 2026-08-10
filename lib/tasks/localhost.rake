# frozen_string_literal: true

namespace :dev do
  desc "Convert the current database to a localhost environment and ensures the standard admin@example.org and system@example.org users are available"
  task :convert_to, [:host] => :environment do |_task, args|
    abort "Please run this task in the development environment only." unless Rails.env.development?
    abort "Please provide a host as an argument. Example: rake dev:convert_to[localhost]" unless args[:host]

    # Update the host in the database to the specified host
    host = args[:host] || "localhost"
    puts "Updating host in the database to #{host}..."
    organization = Decidim::Organization.first
    abort "No organization found in the database." unless organization

    organization.update!(host: host)
    puts "Host updated to #{host} for organization: #{organization.name}"
    organization.update!(users_registration_mode: "enabled")
    puts "Users registration mode updated to 'enabled' for organization: #{organization.name}"

    # Ensure the standard admin@example.org and system@example.org users are available
    admin = organization.admins.find_by(email: "admin@example.org")
    if admin
      puts "Standard admin user already exists: #{admin.email}, updating password..."
      admin.update!(password: "decidim123456789",
                    password_updated_at: Time.current)
    else
      puts "Creating standard admin user..."
      organization.admins.create!(email: "admin@example.org",
                                  nickname: "admin",
                                  name: "Admin",
                                  password: "decidim123456789",
                                  password_updated_at: Time.current,
                                  tos_agreement: true,
                                  accepted_tos_version: Time.current,

                                  confirmed_at: Time.current)

    end
    system = Decidim::System::Admin.find_by(email: "system@example.org")
    if system
      puts "Standard system user already exists: #{system.email}, updating password..."
      system.update!(password: "decidim123456789")
    else
      puts "Creating standard system user..."
      Decidim::System::Admin.create!(email: "system@example.org",
                                     password: "decidim123456789")
    end
  end
end
