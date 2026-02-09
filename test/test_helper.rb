# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "yabeda/gvl_metrics"

require "minitest/autorun"

module YabedaGvlMetricsTestHelpers
  def reset_yabeda!
    Yabeda.reset!
  end

  def reset_plugin_state!
    Yabeda::GvlMetrics.instance_variable_set(:@installed, false)

    if defined?(GvlMetricsMiddleware::Rack)
      GvlMetricsMiddleware::Rack.reporter = nil
    end

    if defined?(GvlMetricsMiddleware::Sidekiq)
      GvlMetricsMiddleware::Sidekiq.reporter = nil
    end

    if GvlMetricsMiddleware.instance_variable_defined?(:@test_sidekiq_reporter)
      GvlMetricsMiddleware.remove_instance_variable(:@test_sidekiq_reporter)
    end
  end

  def stub_gvl_sidekiq!
    return if @sidekiq_stubbed

    @sidekiq_stubbed = true
    @original_sidekiq_method = GvlMetricsMiddleware.method(:sidekiq)
    singleton = class << GvlMetricsMiddleware; self; end
    singleton.define_method(:sidekiq) do |&block|
      if block_given?
        @test_sidekiq_reporter = block
      else
        @test_sidekiq_reporter
      end
    end
  end

  def restore_gvl_sidekiq!
    return unless @sidekiq_stubbed

    singleton = class << GvlMetricsMiddleware; self; end
    singleton.define_method(:sidekiq, @original_sidekiq_method)
    @original_sidekiq_method = nil
    @sidekiq_stubbed = false
  end
end
