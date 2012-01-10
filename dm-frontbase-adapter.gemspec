# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)


Gem::Specification.new do |s|
  s.name        = "dm-frontbase-adapter"
  s.version     = '1.1.0'
  s.authors     = ["zapo"]
  s.email       = ["antoine.niek@supinfo.com"]
  s.homepage    = ""
  s.summary     = %q{gem summary}
  s.description = %q{gem description}

  s.rubyforge_project = "dm-frontbase-adapter"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency 'ruby-frontbase'
  s.add_dependency "dm-core",        "~> 1.1.0"
  s.add_dependency "dm-validations", "~> 1.1.0"
  s.add_dependency "dm-types",       "~> 1.1.0"
end
