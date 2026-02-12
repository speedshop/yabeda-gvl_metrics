# frozen_string_literal: true

require "yabeda"
require "gvl_metrics_middleware"

require_relative "./gvl_metrics/version"

module Yabeda
  module GvlMetrics
    class Error < StandardError; end

    METRIC_GROUP = :gvl_metrics
    METRIC_TAGS = [:source].freeze

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
              record("rack", total, running, io_wait, gvl_wait)
            end
          end

          if sidekiq
            config.sidekiq do |total, running, io_wait, gvl_wait|
              record("sidekiq", total, running, io_wait, gvl_wait)
            end
          end
        end
      end

      def record(source, total, running, io_wait, gvl_wait)
        tags = { source: source }

        Yabeda.gvl_metrics.total.set(tags, total)
        Yabeda.gvl_metrics.running.set(tags, running)
        Yabeda.gvl_metrics.io_wait.set(tags, io_wait)
        Yabeda.gvl_metrics.gvl_wait.set(tags, gvl_wait)
      end
    end
  end
end

require_relative "gvl_metrics/railtie" if defined?(Rails)
