# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoid_logger/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoid_logger"
  spec.version       = MongoidLogger::VERSION
  spec.authors       = ["akima", "nagachika"]
  spec.email         = ["akm2000@gmail.com"]
  spec.description   = %q{Log into both log file and mongodb log collection}
  spec.summary       = %q{Log into both log file and mongodb log collection}
  spec.homepage      = "https://github.com/groovenauts/mongoid_logger"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport", "~> 3.2.11"
  spec.add_runtime_dependency "mongoid", "~> 3.1.3"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
