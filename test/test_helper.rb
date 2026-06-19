# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "yabeda/gvl_metrics"
require "minitest/autorun"

module YabedaGvlMetricsTestHelpers
  def reset_yabeda! = Yabeda.reset!

  def reset_plugin_state!
    Yabeda::GvlMetrics.instance_variable_set(:@installed, false)
    Yabeda::GvlMetrics.instance_variable_set(:@hostname, nil)
    GvlMetricsMiddleware::Rack.reporter = nil if defined?(GvlMetricsMiddleware::Rack)
    GvlMetricsMiddleware::Sidekiq.reporter = nil  if defined?(GvlMetricsMiddleware::Sidekiq)
  end

  # The tag sets each group records with, built the same way the plugin builds
  # them so the lookup matches regardless of the host running the tests.
  def rack_gvl_tags(route: "unknown")
    { hostname: ENV["DYNO"] || Socket.gethostname, pid: Process.pid, route: route }
  end

  def sidekiq_gvl_tags(queue: "", job_class: "")
    {
      hostname: ENV["DYNO"] || Socket.gethostname,
      pid: Process.pid,
      queue: queue,
      job_class: job_class,
    }
  end
end
