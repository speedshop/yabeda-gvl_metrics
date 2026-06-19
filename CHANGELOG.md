## [Unreleased]

### Added

- `route` tag on the Rack GVL metrics, identifying the request's route template — Rails `controller#action` or the matched Sinatra route — as resolved and provided by `gvl_metrics_middleware`. This lets you compare the CPU/IO ratio per action. Only the bounded route template is used (never the raw path), and it falls back to `"unknown"` for unmatched requests. Requires a `gvl_metrics_middleware` version that provides the route to the reporter callback; against older versions `route` is always `"unknown"`.

### Changed

- **Breaking:** GVL metrics are now split into two Yabeda groups, `rack_gvl_metrics` and `sidekiq_gvl_metrics`, so each source declares only the tags relevant to it. Metric names change accordingly — `gvl_metrics_total` becomes `rack_gvl_metrics_total` and `sidekiq_gvl_metrics_total` (and likewise for `running`, `io_wait`, and `gvl_wait`). The `source` tag is removed, since the group name now identifies the source. Rack metrics carry `hostname` and `pid`; Sidekiq metrics carry `hostname`, `pid`, `queue`, and `job_class` (Rack no longer records empty `queue`/`job_class` tags). Update any dashboards or alerts that reference the old `gvl_metrics_*` names or the `source` tag.

## [0.2.0] - 2026-06-19

### Added

- `hostname`, `pid`, `queue`, and `job_class` tags on all GVL metrics. `hostname`/`pid` identify the emitting process (`pid` is read per measurement so it stays correct under forking servers); `queue`/`job_class` segment Sidekiq metrics by the job's queue and class. All values are sourced locally — from within the process and from the data `gvl_metrics_middleware` already passes to the callback — with no `Sidekiq::ProcessSet`/Redis lookup. `queue` and `job_class` are empty for Rack.

## [0.1.0] - 2026-02-09

- Initial release
