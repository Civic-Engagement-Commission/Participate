# frozen_string_literal: true

module Omniauth
  class SwitchController < DecidimController
    def redirect # rubocop:disable Decidim/EnforcePermissionTo
      render :redirect
    end
  end
end
