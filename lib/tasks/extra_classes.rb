# frozen_string_literal: true

require_relative "../../app/models/application_record"

def user_coauthorships(user)
  Decidim::Coauthorship.where(author: user)
end

class UserGroupMembership < ApplicationRecord
  self.table_name = "decidim_user_group_memberships"

  belongs_to :user, class_name: "Decidim::User", foreign_key: :decidim_user_id
  belongs_to :group, class_name: "Decidim::User", foreign_key: :decidim_user_group_id

  scope :member, -> { where(role: %w(creator admin member)) }
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
