# frozen_string_literal: true

module Yabeda
  module GvlMetrics
    class Railtie < ::Rails::Railtie
      config.after_initialize do
        Yabeda::GvlMetrics.configure!
      end
    end
  end
end
