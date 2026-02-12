# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "yabeda/gvl_metrics"
require "minitest/autorun"

module YabedaGvlMetricsTestHelpers
  def reset_yabeda! = Yabeda.reset!

  def reset_plugin_state!
    Yabeda::GvlMetrics.instance_variable_set(:@installed, false)
    GvlMetricsMiddleware::Rack.reporter = nil if defined?(GvlMetricsMiddleware::Rack)
    GvlMetricsMiddleware::Sidekiq.reporter = nil  if defined?(GvlMetricsMiddleware::Sidekiq)
  end
end
