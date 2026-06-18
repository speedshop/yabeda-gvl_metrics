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

    tags = gvl_tags(source: "rack")
    assert_equal 10, Yabeda.gvl_metrics.total.get(tags)
    assert_equal 7, Yabeda.gvl_metrics.running.get(tags)
    assert_equal 2, Yabeda.gvl_metrics.io_wait.get(tags)
    assert_equal 1, Yabeda.gvl_metrics.gvl_wait.get(tags)
  end

  def test_records_sidekiq_metrics
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq
    refute_nil reporter

    reporter.call(20, 9, 5, 6, queue: "default", job_class: "HardJob")

    tags = gvl_tags(source: "sidekiq", queue: "default", job_class: "HardJob")
    assert_equal 20, Yabeda.gvl_metrics.total.get(tags)
    assert_equal 9, Yabeda.gvl_metrics.running.get(tags)
    assert_equal 5, Yabeda.gvl_metrics.io_wait.get(tags)
    assert_equal 6, Yabeda.gvl_metrics.gvl_wait.get(tags)
  end

  def test_sidekiq_metrics_are_segmented_by_queue_and_job_class
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq

    reporter.call(20, 9, 5, 6, queue: "default", job_class: "FastJob")
    reporter.call(40, 10, 20, 10, queue: "mailers", job_class: "SlowJob")

    assert_equal 20, Yabeda.gvl_metrics.total.get(gvl_tags(source: "sidekiq", queue: "default", job_class: "FastJob"))
    assert_equal 40, Yabeda.gvl_metrics.total.get(gvl_tags(source: "sidekiq", queue: "mailers", job_class: "SlowJob"))
  end

  def test_sidekiq_metrics_without_queue_or_job_class
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq

    # An older/newer middleware that does not pass the keywords still records,
    # with empty queue/job_class tags.
    reporter.call(20, 9, 5, 6)

    assert_equal 20, Yabeda.gvl_metrics.total.get(gvl_tags(source: "sidekiq"))
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
    sidekiq_reporter.call(20, 9, 5, 6, queue: "default", job_class: "HardJob")

    rack_tags = gvl_tags(source: "rack")
    assert_equal 10, Yabeda.gvl_metrics.total.get(rack_tags)
    assert_equal 7, Yabeda.gvl_metrics.running.get(rack_tags)
    assert_equal 2, Yabeda.gvl_metrics.io_wait.get(rack_tags)
    assert_equal 1, Yabeda.gvl_metrics.gvl_wait.get(rack_tags)

    sidekiq_tags = gvl_tags(source: "sidekiq", queue: "default", job_class: "HardJob")
    assert_equal 20, Yabeda.gvl_metrics.total.get(sidekiq_tags)
    assert_equal 9, Yabeda.gvl_metrics.running.get(sidekiq_tags)
    assert_equal 5, Yabeda.gvl_metrics.io_wait.get(sidekiq_tags)
    assert_equal 6, Yabeda.gvl_metrics.gvl_wait.get(sidekiq_tags)
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

    assert_equal 10, Yabeda.gvl_metrics.total.get(gvl_tags(source: "rack"))
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
