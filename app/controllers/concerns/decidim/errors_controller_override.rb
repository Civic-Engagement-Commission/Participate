# frozen_string_literal: true

module Decidim
  module ErrorsControllerOverride
    extend ActiveSupport::Concern

    included do
      before_action :delete_headers
      skip_after_action :append_content_security_policy_headers

      def not_found
        head :not_found
      end

      def internal_server_error
        head :internal_server_error
      end

      private

      def delete_headers
        response.delete_header("Content-Security-Policy")
        response.delete_header("Link")
      end
    end
  end
end
