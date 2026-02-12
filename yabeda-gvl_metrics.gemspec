# frozen_string_literal: true

require_relative "lib/yabeda/gvl_metrics/version"

Gem::Specification.new do |spec|
  spec.name = "yabeda-gvl_metrics"
  spec.version = Yabeda::GvlMetrics::VERSION
  spec.authors = ["Nate Berkopec", "Yuki Nishijima"]
  spec.email = ["nate.berkopec@speedshop.co", "yuki.nishijima@speedshop.co"]

  spec.summary = "Yabeda plugin for exporting GVL metrics collected by gvl_metrics_middleware."
  spec.description = "Registers Yabeda gauges for GVL instrumentation and wires middleware callbacks for Rack and Sidekiq."
  spec.homepage = "https://github.com/speedshop/yabeda-gvl_metrics"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/speedshop/yabeda-gvl_metrics"
  spec.metadata["changelog_uri"] = "https://github.com/speedshop/yabeda-gvl_metrics/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile Rakefile .gitignore test/ .github/])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "gvl_metrics_middleware", ">= 0.3.0"
  spec.add_dependency "yabeda", ">= 0.6"
end
