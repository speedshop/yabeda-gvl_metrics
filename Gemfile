# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Temporary: gvl_metrics_middleware 0.4.0 is tagged on GitHub but not yet published
# to RubyGems. Point at the tag so the bundle satisfies the gemspec's ">= 0.4.0"
# requirement. Remove this once 0.4.0 is released on RubyGems.
gem "gvl_metrics_middleware", git: "https://github.com/speedshop/gvl_metrics_middleware.git", tag: "v0.4.0"

gem "irb"
gem "minitest", "~> 5.16"
gem "rake", "~> 13.0"
gem "sidekiq"
