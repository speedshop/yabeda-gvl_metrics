# Yabeda::GvlMetrics

Yabeda plugin for exporting GVL metrics collected by `gvl_metrics_middleware`. It registers gauges in Yabeda and wires
the middleware callbacks for Rack and Sidekiq.

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

In Rails, the Railtie auto-configures the plugin after initialization.

If you want to configure it manually or disable one source (e.g. only for sidekiq), add an initializer:

```ruby
require "yabeda/gvl_metrics"

Yabeda::GvlMetrics.configure!(rack: true, sidekiq: false)
```

## Metrics

All metrics are gauges in the `gvl_metrics` group, reported in nanoseconds. For metric definitions, see:
https://github.com/speedshop/gvl_metrics_middleware?tab=readme-ov-file#available-metrics

For Rack:

- `Custom/gvl_metrics/rack/total`
- `Custom/gvl_metrics/rack/running`
- `Custom/gvl_metrics/rack/io_wait`
- `Custom/gvl_metrics/rack/gvl_wait`

For Sidekiq:

- `Custom/gvl_metrics/sidekiq/total`
- `Custom/gvl_metrics/sidekiq/running`
- `Custom/gvl_metrics/sidekiq/io_wait`
- `Custom/gvl_metrics/sidekiq/gvl_wait`

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for
collaboration, and contributors are expected to adhere to the code of conduct.
