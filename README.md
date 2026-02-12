# Yabeda::GvlMetrics

Yabeda plugin for exporting GVL metrics collected by [`gvl_metrics_middleware`](https://github.com/speedshop/gvl_metrics_middleware). It registers gauges in Yabeda and wires the middleware callbacks for Rack and Sidekiq.

## Requirements

- Ruby >= 3.2.0
- [`gvl_metrics_middleware`](https://github.com/speedshop/gvl_metrics_middleware) >= 0.3.0
- [`yabeda`](https://github.com/yabeda-rb/yabeda) >= 0.6

## Installation

Add the gem to your Gemfile:

```ruby
gem "yabeda-gvl_metrics"
```

Then run:

```bash
bundle install
```

## Usage

In Rails, the Railtie auto-configures the plugin after initialization. It detects which frameworks are loaded (Rack and/or Sidekiq) and only wires the middleware for the ones that are present.

If you call `Yabeda::GvlMetrics.configure!` manually in an initializer, the Railtie will detect that the plugin is already configured and skip its own setup.

To configure it manually or disable one source (e.g. only for Sidekiq), add an initializer:

```ruby
require "yabeda/gvl_metrics"

Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
```

For non-Rails applications, call `configure!` directly after requiring the gem.

## Metrics

All metrics are registered as Yabeda gauges in the `gvl_metrics` group with a `source` tag, reported in nanoseconds. Each gauge holds the value from the most recent request or job.

For metric definitions, see: https://github.com/speedshop/gvl_metrics_middleware?tab=readme-ov-file#available-metrics

| Metric | Tag | Description |
|--------|-----|-------------|
| `gvl_metrics_total` | `source: "rack"` or `source: "sidekiq"` | Total time (running + io_wait + gvl_wait) |
| `gvl_metrics_running` | `source: "rack"` or `source: "sidekiq"` | Time spent running Ruby code |
| `gvl_metrics_io_wait` | `source: "rack"` or `source: "sidekiq"` | Time spent waiting on IO |
| `gvl_metrics_gvl_wait` | `source: "rack"` or `source: "sidekiq"` | Time spent waiting on the GVL |

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for
collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
