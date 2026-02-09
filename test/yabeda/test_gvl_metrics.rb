# frozen_string_literal: true

require "test_helper"

class Yabeda::TestGvlMetrics < Minitest::Test
  include YabedaGvlMetricsTestHelpers

  def setup
    reset_yabeda!
    reset_plugin_state!
  end

  def teardown
    restore_gvl_sidekiq!
    reset_plugin_state!
    reset_yabeda!
  end

  def test_that_it_has_a_version_number
    refute_nil ::Yabeda::GvlMetrics::VERSION
  end

  def test_records_rack_metrics
    Yabeda::GvlMetrics.configure!(sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    refute_nil reporter

    reporter.call(10, 7, 2, 1)

    assert_equal 10, Yabeda.gvl_metrics.total.get(source: "rack")
    assert_equal 7, Yabeda.gvl_metrics.running.get(source: "rack")
    assert_equal 2, Yabeda.gvl_metrics.io_wait.get(source: "rack")
    assert_equal 1, Yabeda.gvl_metrics.gvl_wait.get(source: "rack")
  end

  def test_records_sidekiq_metrics
    stub_gvl_sidekiq!
    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq
    refute_nil reporter

    reporter.call(20, 9, 5, 6)

    assert_equal 20, Yabeda.gvl_metrics.total.get(source: "sidekiq")
    assert_equal 9, Yabeda.gvl_metrics.running.get(source: "sidekiq")
    assert_equal 5, Yabeda.gvl_metrics.io_wait.get(source: "sidekiq")
    assert_equal 6, Yabeda.gvl_metrics.gvl_wait.get(source: "sidekiq")
  end
end
