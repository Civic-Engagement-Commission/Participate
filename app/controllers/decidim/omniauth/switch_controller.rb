# frozen_string_literal: true

module Decidim
  module Omniauth
    class SwitchController < DecidimController
      def redirect
        redirect_post("/users/auth/#{params["provider"]}", params: { authenticity_token: form_authenticity_token })
      end
    end
  end
end
