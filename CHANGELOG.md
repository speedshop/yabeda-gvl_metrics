## [Unreleased]

### Added

- `hostname`, `pid`, `queue`, and `job_class` tags on all GVL metrics. `hostname`/`pid` identify the emitting process (`pid` is read per measurement so it stays correct under forking servers); `queue`/`job_class` segment Sidekiq metrics by the job's queue and class. All values are sourced locally — from within the process and from the data `gvl_metrics_middleware` already passes to the callback — with no `Sidekiq::ProcessSet`/Redis lookup. `queue` and `job_class` are empty for Rack.

## [0.1.0] - 2026-02-09

- Initial release
