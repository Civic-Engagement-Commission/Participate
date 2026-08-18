# frozen_string_literal: true

require_relative "../../app/models/application_record"

def user_coauthorships(user)
  Decidim::Coauthorship.where(author: user)
end

namespace :nyc do
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
        existing_user = Decidim::User.find_by(email: email)
        if group.email != email && existing_user && user_coauthorships(existing_user).exists?
          puts "User #{email} has coauthorships, moving #{user_coauthorships(existing_user).count} coauthorships to group #{group.id}..."
          Decidim::Coauthorship.where(author: existing_user).update_all(decidim_author_id: group.id) # rubocop:disable Rails/SkipsModelValidations

          puts "Coauthorships moved, skipping group processing, please delete USER first"
          next
        end
        puts "CHANGE TO #{email}"
        begin
          group.skip_reconfirmation!
          group.update!(email:) unless group.email == email
        rescue StandardError => e
          puts "ERROR: #{e.message}, SKIPPED"
        end
      else
        puts "SKIP"
      end
    end
  end

  desc "Remove user groups memberships"
  task remove_user_group_memberships: :environment do
    class UserGroupMembership < ApplicationRecord
      self.table_name = "decidim_user_group_memberships"

      belongs_to :user, class_name: "Decidim::User", foreign_key: :decidim_user_id
      belongs_to :group, class_name: "Decidim::User", foreign_key: :decidim_user_group_id

      scope :member, -> { where(role: %w(creator admin member)) }
    end
    puts "Removing #{UserGroupMembership.count} user group memberships..."
    UserGroupMembership.delete_all
    puts "User group memberships removed."
  end

  desc "Delete users"
  task :delete_users, [:file] => :environment do |_task, args|
    file = args[:file].to_s
    unless File.exist?(file)
      puts "File not found! [#{file}]"
      puts
      puts "Usage: rake nyc:delete_users[<file>]"
      puts
      puts "The file should be a CSV with the following format:"
      puts "email"
      puts "Example:"
      puts "email@example.com"
      abort
    end

    class SilentDestroyAccount < Decidim::DestroyAccount
      def call
        return broadcast(:invalid) unless @form.valid?

        destroy_user_account!
        destroy_user_identities
        destroy_follows
        destroy_user_versions
        destroy_user_private_exports
        destroy_user_access_grants
        destroy_user_access_tokens
        destroy_user_reminders
        destroy_user_notifications
        destroy_user_badges
        destroy_user_likes
        destroy_user_reports
        destroy_participatory_space_private_user
        delegate_destroy_to_participatory_spaces

        broadcast(:ok)
      end
    end

    emails = []
    CSV.foreach(file, headers: false) do |row|
      emails << row[0]
    end

    puts "Removing #{Decidim::User.where(email: emails).count} users..."

    emails.each do |email|
      user = Decidim::User.find_by(email:)
      next unless user

      puts "Deleting user: #{user.email}"
      if user_coauthorships(user).any?
        puts "ERROR: User #{user.email} HAS BEEN SKIPPED, User has proposals."
        puts "Coauthorships: #{user_coauthorships(user).count}"
        next
      end

      puts "Destroying user: #{user.email}"
      SilentDestroyAccount.call(
        Decidim::DeleteAccountForm.from_params(
          delete_reason: I18n.t("decidim.account.destroy.inactive_account_removal_reason", inactivity_period: Decidim.delete_inactive_users_after_days)
        ).with_context(current_user: user)
      )
    end
    puts "Users removed."
  end
end
