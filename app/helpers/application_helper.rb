# frozen_string_literal: true

module ApplicationHelper
  def omniauth_sign_up_url(config)
    return if config[:sign_up_button_url].blank?

    uri = URI(config[:sign_up_button_url])
    uri.query = {
      showNameFields: "false",
      lang: current_locale,
      spName: config[:sign_up_button_sp_name],
      target: Base64.urlsafe_encode64(config[:sign_up_button_target])
    }.to_query

    uri.to_s
  end
end
