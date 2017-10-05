# coding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-typetalk"
  spec.version       = "0.2.0"
  spec.authors       = ["tksmd","umakoz"]
  spec.email         = ["someda@isenshi.com"]
  spec.description   = %q{fluent plugin to send message to typetalk}
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/nulab/fluent-plugin-typetalk"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", ">= 0.9.2"
  spec.add_development_dependency "test-unit", ">= 3.1.0"
  spec.add_development_dependency "test-unit-rr", ">= 1.0.5"

  spec.add_runtime_dependency "fluentd", [">= 0.14.0", "< 2"]
  spec.add_runtime_dependency "typetalk", ">= 0.1.0"
end
