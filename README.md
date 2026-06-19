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

All metrics are registered as Yabeda gauges in the `gvl_metrics` group, reported in nanoseconds. Each gauge holds the value from the most recent request or job for a given set of tags.

For metric definitions, see: https://github.com/speedshop/gvl_metrics_middleware?tab=readme-ov-file#available-metrics

| Metric | Description |
|--------|-------------|
| `gvl_metrics_total` | Total time (running + io_wait + gvl_wait) |
| `gvl_metrics_running` | Time spent running Ruby code |
| `gvl_metrics_io_wait` | Time spent waiting on IO |
| `gvl_metrics_gvl_wait` | Time spent waiting on the GVL |

### Tags

Every metric carries the following tags, so you can attribute GVL time to a specific process and, for Sidekiq, to the job that ran:

| Tag | Description |
|-----|-------------|
| `source` | `"rack"` or `"sidekiq"` |
| `hostname` | Host the process runs on (`ENV["DYNO"]` if set, otherwise `Socket.gethostname` — the same value Sidekiq reports for itself) |
| `pid` | Process ID. Read fresh on every measurement, so it stays correct under forking servers (e.g. Puma in cluster mode) |
| `queue` | Sidekiq only: the queue the job was pulled from. Empty for Rack. |
| `job_class` | Sidekiq only: the job's class name. Empty for Rack. |

The `hostname`, `pid`, `queue`, and `job_class` values are read locally from within the running process and from the data `gvl_metrics_middleware` already passes to the callback — there is no `Sidekiq::ProcessSet`/Redis lookup involved.

> **Cardinality:** `queue` and especially `job_class` multiply the number of time series per process (one series per `source`/`queue`/`job_class` combination), and `pid` produces a new series for every restart or redeploy. On apps with many job classes this can add up — keep an eye on your metrics backend's cardinality.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for
collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
