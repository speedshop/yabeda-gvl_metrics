# frozen_string_literal: true

require "test_helper"

class Yabeda::TestGvlMetrics < Minitest::Test
  include YabedaGvlMetricsTestHelpers

  def setup
    reset_yabeda!
    reset_plugin_state!
  end

  def teardown
    reset_plugin_state!
    reset_yabeda!
  end

  def test_records_rack_metrics
    ensure_rack_loaded!

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
    ensure_sidekiq_loaded!

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

  def test_records_both_rack_and_sidekiq_metrics
    ensure_rack_loaded!
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!
    Yabeda.configure!

    rack_reporter = GvlMetricsMiddleware.rack
    sidekiq_reporter = GvlMetricsMiddleware.sidekiq
    refute_nil rack_reporter
    refute_nil sidekiq_reporter

    rack_reporter.call(10, 7, 2, 1)
    sidekiq_reporter.call(20, 9, 5, 6)

    assert_equal 10, Yabeda.gvl_metrics.total.get(source: "rack")
    assert_equal 7, Yabeda.gvl_metrics.running.get(source: "rack")
    assert_equal 2, Yabeda.gvl_metrics.io_wait.get(source: "rack")
    assert_equal 1, Yabeda.gvl_metrics.gvl_wait.get(source: "rack")

    assert_equal 20, Yabeda.gvl_metrics.total.get(source: "sidekiq")
    assert_equal 9, Yabeda.gvl_metrics.running.get(source: "sidekiq")
    assert_equal 5, Yabeda.gvl_metrics.io_wait.get(source: "sidekiq")
    assert_equal 6, Yabeda.gvl_metrics.gvl_wait.get(source: "sidekiq")
  end

  def test_configure_is_idempotent
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    refute_nil reporter

    reporter.call(10, 7, 2, 1)

    # Second call should be a no-op
    Yabeda::GvlMetrics.configure!(sidekiq: false)

    assert_equal 10, Yabeda.gvl_metrics.total.get(source: "rack")
  end

  def test_default_configure_does_not_require_sidekiq
    with_sidekiq_unloaded do
      ensure_rack_loaded!

      Yabeda::GvlMetrics.configure!
      Yabeda.configure!

      refute_nil GvlMetricsMiddleware.rack
      assert_nil GvlMetricsMiddleware::Sidekiq.reporter if defined?(GvlMetricsMiddleware::Sidekiq)
    end
  end

  private

  def ensure_sidekiq_loaded!
    require "sidekiq/version"
  end

  def ensure_rack_loaded!
    require "rack"
  end

  def with_sidekiq_unloaded
    had_sidekiq = Object.const_defined?(:Sidekiq)
    previous_sidekiq = ::Sidekiq if had_sidekiq
    Object.send(:remove_const, :Sidekiq) if had_sidekiq
    yield
  ensure
    Object.const_set(:Sidekiq, previous_sidekiq) if had_sidekiq && !Object.const_defined?(:Sidekiq)
  end
end
