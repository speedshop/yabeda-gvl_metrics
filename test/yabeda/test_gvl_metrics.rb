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

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    refute_nil reporter

    reporter.call(10, 7, 2, 1)

    tags = rack_gvl_tags
    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(tags)
    assert_equal 7, Yabeda.rack_gvl_metrics.running.get(tags)
    assert_equal 2, Yabeda.rack_gvl_metrics.io_wait.get(tags)
    assert_equal 1, Yabeda.rack_gvl_metrics.gvl_wait.get(tags)
  end

  def test_records_sidekiq_metrics
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq
    refute_nil reporter

    reporter.call(20, 9, 5, 6, queue: "default", job_class: "HardJob")

    tags = sidekiq_gvl_tags(queue: "default", job_class: "HardJob")
    assert_equal 20, Yabeda.sidekiq_gvl_metrics.total.get(tags)
    assert_equal 9, Yabeda.sidekiq_gvl_metrics.running.get(tags)
    assert_equal 5, Yabeda.sidekiq_gvl_metrics.io_wait.get(tags)
    assert_equal 6, Yabeda.sidekiq_gvl_metrics.gvl_wait.get(tags)
  end

  def test_sidekiq_metrics_are_segmented_by_queue_and_job_class
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq

    reporter.call(20, 9, 5, 6, queue: "default", job_class: "FastJob")
    reporter.call(40, 10, 20, 10, queue: "mailers", job_class: "SlowJob")

    assert_equal 20, Yabeda.sidekiq_gvl_metrics.total.get(sidekiq_gvl_tags(queue: "default", job_class: "FastJob"))
    assert_equal 40, Yabeda.sidekiq_gvl_metrics.total.get(sidekiq_gvl_tags(queue: "mailers", job_class: "SlowJob"))
  end

  def test_sidekiq_metrics_without_queue_or_job_class
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.sidekiq

    # An older/newer middleware that does not pass the keywords still records,
    # with empty queue/job_class tags.
    reporter.call(20, 9, 5, 6)

    assert_equal 20, Yabeda.sidekiq_gvl_metrics.total.get(sidekiq_gvl_tags)
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

    rack_tags = rack_gvl_tags
    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(rack_tags)
    assert_equal 7, Yabeda.rack_gvl_metrics.running.get(rack_tags)
    assert_equal 2, Yabeda.rack_gvl_metrics.io_wait.get(rack_tags)
    assert_equal 1, Yabeda.rack_gvl_metrics.gvl_wait.get(rack_tags)

    sidekiq_tags = sidekiq_gvl_tags(queue: "default", job_class: "HardJob")
    assert_equal 20, Yabeda.sidekiq_gvl_metrics.total.get(sidekiq_tags)
    assert_equal 9, Yabeda.sidekiq_gvl_metrics.running.get(sidekiq_tags)
    assert_equal 5, Yabeda.sidekiq_gvl_metrics.io_wait.get(sidekiq_tags)
    assert_equal 6, Yabeda.sidekiq_gvl_metrics.gvl_wait.get(sidekiq_tags)
  end

  def test_rack_and_sidekiq_have_separate_groups_with_their_own_tags
    ensure_rack_loaded!
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!
    Yabeda.configure!

    assert_equal %i[hostname pid route], Yabeda.rack_gvl_metrics.total.tags
    assert_equal %i[hostname pid queue job_class], Yabeda.sidekiq_gvl_metrics.total.tags
  end

  def test_rack_route_is_recorded_from_the_reporter_keyword
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    # gvl_metrics_middleware resolves the route and passes it as a keyword.
    reporter.call(10, 7, 2, 1, route: "admin/users#index")

    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(rack_gvl_tags(route: "admin/users#index"))
  end

  def test_rack_route_falls_back_to_unknown_without_a_route_keyword
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    # Older gvl_metrics_middleware calls the reporter without a route keyword.
    reporter.call(10, 7, 2, 1)

    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(rack_gvl_tags(route: "unknown"))
  end

  def test_rack_route_falls_back_to_unknown_when_route_is_nil
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    # The middleware passes route: nil when no route matched (404s, plain Rack).
    reporter.call(10, 7, 2, 1, route: nil)

    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(rack_gvl_tags(route: "unknown"))
  end

  def test_rack_only_configure_defines_only_the_rack_group
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    assert Yabeda.groups.key?(:rack_gvl_metrics)
    refute Yabeda.groups.key?(:sidekiq_gvl_metrics)
  end

  def test_sidekiq_only_configure_defines_only_the_sidekiq_group
    ensure_sidekiq_loaded!

    Yabeda::GvlMetrics.configure!(rack: false, sidekiq: true)
    Yabeda.configure!

    assert Yabeda.groups.key?(:sidekiq_gvl_metrics)
    refute Yabeda.groups.key?(:rack_gvl_metrics)
  end

  def test_configure_is_idempotent
    ensure_rack_loaded!

    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
    Yabeda.configure!

    reporter = GvlMetricsMiddleware.rack
    refute_nil reporter

    reporter.call(10, 7, 2, 1)

    # Second call should be a no-op
    Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)

    assert_equal 10, Yabeda.rack_gvl_metrics.total.get(rack_gvl_tags)
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
