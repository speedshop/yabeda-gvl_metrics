# frozen_string_literal: true

require "socket"

require "yabeda"
require "gvl_metrics_middleware"

require_relative "./gvl_metrics/version"

module Yabeda
  module GvlMetrics
    class Error < StandardError; end

    RACK_GROUP = :rack_gvl_metrics
    SIDEKIQ_GROUP = :sidekiq_gvl_metrics

    # Rack and Sidekiq each get their own group so a group only declares the tags
    # that make sense for it. Rack carries +route+ (the request's controller#action
    # on Rails, or the matched route template on Sinatra); Sidekiq carries +queue+
    # and +job_class+. The group name already tells the two sources apart, so there
    # is no separate +source+ tag.
    RACK_TAGS = %i[hostname pid route].freeze
    SIDEKIQ_TAGS = %i[hostname pid queue job_class].freeze

    class << self
      def configure!(rack: defined?(::Rack), sidekiq: defined?(::Sidekiq))
        return if @installed

        define_metrics(rack: rack, sidekiq: sidekiq)
        hook_middleware(rack: rack, sidekiq: sidekiq)

        @installed = true
      end

      private

      def define_metrics(rack:, sidekiq:)
        Yabeda.configure do
          if rack
            group RACK_GROUP do
              gauge :total, tags: RACK_TAGS, comment: "Total time in nanoseconds (running + io_wait + gvl_wait)."
              gauge :running, tags: RACK_TAGS, comment: "Time in nanoseconds spent running Ruby code."
              gauge :io_wait, tags: RACK_TAGS, comment: "Time in nanoseconds spent waiting on IO."
              gauge :gvl_wait, tags: RACK_TAGS, comment: "Time in nanoseconds spent waiting on the GVL."
            end
          end

          if sidekiq
            group SIDEKIQ_GROUP do
              gauge :total, tags: SIDEKIQ_TAGS, comment: "Total time in nanoseconds (running + io_wait + gvl_wait)."
              gauge :running, tags: SIDEKIQ_TAGS, comment: "Time in nanoseconds spent running Ruby code."
              gauge :io_wait, tags: SIDEKIQ_TAGS, comment: "Time in nanoseconds spent waiting on IO."
              gauge :gvl_wait, tags: SIDEKIQ_TAGS, comment: "Time in nanoseconds spent waiting on the GVL."
            end
          end
        end
      end

      def hook_middleware(rack:, sidekiq:)
        GvlMetricsMiddleware.configure do |config|
          if rack
            # gvl_metrics_middleware resolves the request's route and passes it to
            # this callback (as a keyword) starting in the version that added it;
            # +route: nil+ keeps us working against older versions, where it simply
            # falls back to "unknown".
            config.rack do |total, running, io_wait, gvl_wait, route: nil|
              record_rack(total, running, io_wait, gvl_wait, route: route)
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

      def record_rack(total, running, io_wait, gvl_wait, route: nil)
        # gvl_metrics_middleware resolves the route (Rails controller#action or the
        # Sinatra route) and passes it in. It is nil on older middleware or when no
        # route matched, in which case we record a fixed "unknown" bucket.
        tags = { hostname: hostname, pid: ::Process.pid, route: route || "unknown" }

        write_metrics(Yabeda.rack_gvl_metrics, tags, total, running, io_wait, gvl_wait)
      end

      def record_sidekiq(total, running, io_wait, gvl_wait, queue: nil, job_class: nil)
        tags = { hostname: hostname, pid: ::Process.pid, queue: queue.to_s, job_class: job_class.to_s }

        write_metrics(Yabeda.sidekiq_gvl_metrics, tags, total, running, io_wait, gvl_wait)
      end

      def write_metrics(group, tags, total, running, io_wait, gvl_wait)
        group.total.set(tags, total)
        group.running.set(tags, running)
        group.io_wait.set(tags, io_wait)
        group.gvl_wait.set(tags, gvl_wait)
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
