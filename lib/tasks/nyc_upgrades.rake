# frozen_string_literal: true

require_relative "../../app/models/application_record"

namespace :nyc do
  module Decidim
    class UserGroupMembership < ApplicationRecord
      self.table_name = "decidim_user_group_memberships"

      belongs_to :user, class_name: "Decidim::User", foreign_key: :decidim_user_id
      belongs_to :group, class_name: "Decidim::User", foreign_key: :decidim_user_group_id

      scope :member, -> { where(role: %w(creator admin member)) }
    end
  end

  desc "Patch user groups emails"
  task :patch_user_groups_emails, [:file] => :environment do |_task, args|
    file = args[:file].to_s
    unless File.exist?(file)
      puts "File not found! [#{file}]"
      puts
      puts "Usage: rake nyc:patch_user_groups_emails[<file>]"
      puts
      puts "The file should be a CSV with the following format:"
      puts "email, new_email"
      puts "Example:"
      puts "old_email@example.com, new_email@example.com"
      abort
    end

    emails = {}
    CSV.foreach(file, headers: false) do |row|
      emails[row[0]] = row[1]
    end

    Decidim::User.user_group.where(encrypted_password: "").find_each do |group|
      email = emails[group.email]
      email ||= emails[group.extended_data["previous_email"]]
      puts "#{group.email} - #{group.nickname} - #{group.name} Ext: #{group.extended_data["previous_email"]}"
      if group.invalid?
        puts "INVALID: #{group.errors.full_messages.join(", ")}"
        group.update!(nickname: Decidim::User.nicknamize(group.name, group.organization))
      end
      if email
        puts "CHANGE TO #{email}"
        group.skip_reconfirmation!
        group.update!(email:) unless group.email == email
      else
        puts "SKIP"
      end
    end
  end

  desc "Remove user groups memberships"
  task remove_user_group_memberships: :environment do
    puts "Removing #{Decidim::UserGroupMembership.count} user group memberships..."
    Decidim::UserGroupMembership.delete_all
    puts "User group memberships removed."
  end
end
