# frozen_string_literal: true

require "socket"

require "yabeda"
require "gvl_metrics_middleware"

require_relative "./gvl_metrics/version"

module Yabeda
  module GvlMetrics
    class Error < StandardError; end

    METRIC_GROUP = :gvl_metrics
    METRIC_TAGS = %i[source hostname pid queue job_class].freeze

    class << self
      def configure!(rack: defined?(::Rack), sidekiq: defined?(::Sidekiq))
        return if @installed

        define_metrics
        hook_middleware(rack: rack, sidekiq: sidekiq)

        @installed = true
      end

      private

      def define_metrics
        Yabeda.configure do
          group METRIC_GROUP do
            gauge :total, tags: METRIC_TAGS, comment: "Total time in nanoseconds (running + io_wait + gvl_wait)."
            gauge :running, tags: METRIC_TAGS, comment: "Time in nanoseconds spent running Ruby code."
            gauge :io_wait, tags: METRIC_TAGS, comment: "Time in nanoseconds spent waiting on IO."
            gauge :gvl_wait, tags: METRIC_TAGS, comment: "Time in nanoseconds spent waiting on the GVL."
          end
        end
      end

      def hook_middleware(rack:, sidekiq:)
        GvlMetricsMiddleware.configure do |config|
          if rack
            config.rack do |total, running, io_wait, gvl_wait|
              record_rack(total, running, io_wait, gvl_wait)
            end
          end

          if sidekiq
            # gvl_metrics_middleware already hands the current job's queue and
            # class to the callback as keyword arguments, so we can segment by
            # them without any Sidekiq::ProcessSet/Redis lookup. They are given
            # defaults so this stays compatible with any middleware version that
            # does not send them.
            config.sidekiq do |total, running, io_wait, gvl_wait, queue: nil, job_class: nil|
              record_sidekiq(total, running, io_wait, gvl_wait, queue: queue, job_class: job_class)
            end
          end
        end
      end

      def record_rack(total, running, io_wait, gvl_wait)
        # Rack jobs have no queue or job class, but the tags are still set (to an
        # empty string) so that every series of a metric shares the same label set.
        tags = { source: "rack", hostname: hostname, pid: ::Process.pid, queue: "", job_class: "" }

        write_metrics(tags, total, running, io_wait, gvl_wait)
      end

      def record_sidekiq(total, running, io_wait, gvl_wait, queue: nil, job_class: nil)
        tags = {
          source: "sidekiq",
          hostname: hostname,
          pid: ::Process.pid,
          queue: queue.to_s,
          job_class: job_class.to_s,
        }

        write_metrics(tags, total, running, io_wait, gvl_wait)
      end

      def write_metrics(tags, total, running, io_wait, gvl_wait)
        Yabeda.gvl_metrics.total.set(tags, total)
        Yabeda.gvl_metrics.running.set(tags, running)
        Yabeda.gvl_metrics.io_wait.set(tags, io_wait)
        Yabeda.gvl_metrics.gvl_wait.set(tags, gvl_wait)
      end

      # The host name does not change across a fork, so memoizing it (even if the
      # value is inherited by a forked worker) is safe. The pid, which does change
      # on fork, is read fresh on every call instead, so it stays correct under
      # forking servers such as Puma in cluster mode. This mirrors how Sidekiq
      # itself derives its hostname.
      def hostname
        @hostname ||= ENV["DYNO"] || Socket.gethostname
      end
    end
  end
end

require_relative "gvl_metrics/railtie" if defined?(Rails)
