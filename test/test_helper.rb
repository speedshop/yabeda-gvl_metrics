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

  # The full tag set every gauge is recorded with. Built the same way the plugin
  # builds it, so the lookup matches regardless of the host running the tests.
  def gvl_tags(source:, queue: "", job_class: "")
    {
      source: source,
      hostname: ENV["DYNO"] || Socket.gethostname,
      pid: Process.pid,
      queue: queue,
      job_class: job_class,
    }
  end
end
