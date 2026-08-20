# frozen_string_literal: true

namespace :nyc do
  desc "Patch user groups emails"
  task :patch_user_groups_emails, [:file] => :environment do |_task, args|
    require_relative "extra_classes"

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
        puts "ASSIGN GROUP MEMBERS COAUTHORSHIPS TO GROUP #{group.id}"
        UserGroupMembership.where(group: group).find_each do |membership|
          coauthorships = user_coauthorships(membership.user).where(decidim_user_group_id: group.id)
          coauthorships.find_each do |coauthorship|
            puts "Moving coauthorship #{coauthorship.id} from author #{coauthorship.decidim_author_id} to group #{coauthorship.decidim_user_group_id}"
            coauthorship.update(decidim_author_id: coauthorship.decidim_user_group_id)
          end
        end

        existing_user = Decidim::User.find_by(email: email)
        coauthorships = user_coauthorships(existing_user)
        if existing_user != group && group.email != email && existing_user && coauthorships.exists?
          puts "USER #{email} HAS COAUTHORSHIPS, moving #{coauthorships.count} coauthorships to group #{group.id}..."
          Decidim::Coauthorship.where(decidim_author_id: existing_user.id).update_all(decidim_author_id: group.id) # rubocop:disable Rails/SkipsModelValidations

          puts "#{coauthorships.count} coauthorships moved"

          puts "REMOVE EXISTING USER..."
          puts "Destroying user: #{existing_user.email}"
          SilentDestroyAccount.call(
            Decidim::DeleteAccountForm.from_params(
              delete_reason: "Upgraded to user group #{group.id} (#{email})"
            ).with_context(current_user: existing_user)
          )
        end

        puts "CHANGE EMAIL FROM #{group.email} TO #{email}..."
        begin
          group.skip_reconfirmation!
          group.update!(email: email) unless group.email == email
        rescue StandardError => e
          puts "ERROR: #{e.message}, SKIPPED"
        end
      else
        puts "GROUP #{group.id} SKIPPED (no email)"
      end
    end
  end

  desc "Remove user groups memberships"
  task remove_user_group_memberships: :environment do
    require_relative "extra_classes"

    puts "Removing #{UserGroupMembership.count} user group memberships..."
    UserGroupMembership.delete_all
    puts "User group memberships removed."
  end

  desc "Delete users"
  task :delete_users, [:file] => :environment do |_task, args|
    require_relative "extra_classes"

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
