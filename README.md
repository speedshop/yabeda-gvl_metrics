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

Metrics are registered as Yabeda gauges, reported in nanoseconds. Each gauge holds the value from the most recent request or job for a given set of tags. Rack and Sidekiq each have their own group, so a group only carries the tags that make sense for it — the group name distinguishes the two sources, so there is no separate `source` tag.

For metric definitions, see: https://github.com/speedshop/gvl_metrics_middleware?tab=readme-ov-file#available-metrics

### Rack — group `rack_gvl_metrics`

| Metric | Description |
|--------|-------------|
| `rack_gvl_metrics_total` | Total time (running + io_wait + gvl_wait) |
| `rack_gvl_metrics_running` | Time spent running Ruby code |
| `rack_gvl_metrics_io_wait` | Time spent waiting on IO |
| `rack_gvl_metrics_gvl_wait` | Time spent waiting on the GVL |

Tags: `hostname`, `pid`, `route`.

### Sidekiq — group `sidekiq_gvl_metrics`

| Metric | Description |
|--------|-------------|
| `sidekiq_gvl_metrics_total` | Total time (running + io_wait + gvl_wait) |
| `sidekiq_gvl_metrics_running` | Time spent running Ruby code |
| `sidekiq_gvl_metrics_io_wait` | Time spent waiting on IO |
| `sidekiq_gvl_metrics_gvl_wait` | Time spent waiting on the GVL |

Tags: `hostname`, `pid`, `queue`, `job_class`.

### Tags

These let you attribute GVL time to a specific process and, for Sidekiq, to the job that ran:

| Tag | Applies to | Description |
|-----|------------|-------------|
| `hostname` | Rack, Sidekiq | Host the process runs on (`ENV["DYNO"]` if set, otherwise `Socket.gethostname` — the same value Sidekiq reports for itself) |
| `pid` | Rack, Sidekiq | Process ID. Read fresh on every measurement, so it stays correct under forking servers (e.g. Puma in cluster mode) |
| `route` | Rack | The request's route template — Rails `controller#action` (e.g. `users#show`, `admin/users#index`) or the matched Sinatra route (e.g. `GET /users/:id`), as resolved by `gvl_metrics_middleware`. This lets you compare the CPU/IO ratio per action. Falls back to `"unknown"` when no route matched (404s, non-Rails/Sinatra Rack apps) or when running against a `gvl_metrics_middleware` version that does not provide the route to the callback. |
| `queue` | Sidekiq | The queue the job was pulled from |
| `job_class` | Sidekiq | The job's class name |

The `hostname`, `pid`, `queue`, and `job_class` values are read locally from within the running process and from the data `gvl_metrics_middleware` already passes to the callback — there is no `Sidekiq::ProcessSet`/Redis lookup involved. `route` is the request's resolved route *template* (the matched controller#action or route pattern), never the raw path, so it stays bounded by the number of routes rather than growing with every distinct URL.

> **Note:** The `route` tag only resolves to real values when `gvl_metrics_middleware` provides the route to the reporter callback. Against versions that don't, `route` is always `"unknown"` and the rest of the metrics are unaffected.

> **Cardinality:** on the Rack metrics, `route` adds one series per route template per process; on the Sidekiq metrics, `queue` and especially `job_class` multiply series the same way. Across both, `pid` produces a new series for every restart or redeploy. Route templates and job classes are bounded by your app, but on apps with many of them this can add up — keep an eye on your metrics backend's cardinality.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for
collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
