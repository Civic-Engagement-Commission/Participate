# frozen_string_literal: true

module Omniauth
  class SwitchController < DecidimController
    protected

    def redirect
      render :redirect
    end
  end
end
