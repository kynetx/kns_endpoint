require 'rake'

Gem::Specification.new do |s|
  s.name = %q{kns_endpoint}
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Michael Farmer"]
  s.date = %q{2010-09-24}
  s.email = %q{mjf@kynetx.com}
  s.extra_rdoc_files = ["LICENSE"]
  s.homepage = %q{http://github.com/kynetx/kns_endpoint}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.has_rdoc = false
  s.summary = %q{Creates a Kynetx KNS Endpoint}

  s.description = <<-EOF
    Build a Kynetx Endpoint in Ruby. Adds the ability to raise, or signal, events on the KNS Platform with
    a simple DSL to your existing or new ruby scripts or applications.
  EOF

  s.files = FileList['lib/**/*.rb', 'tests/**/*', "LICENSE"].to_a

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, ["~> 1.2.4"])
      s.add_runtime_dependency(%q<rest-client>, [">= 1.6.1"])
    else
      s.add_dependency(%q<json>, ["~> 1.2.4"])
      s.add_dependency(%q<rest-client>, [">= 1.6.1"])
      s.add_development_dependency('rspec')
    end
  else
    s.add_dependency(%q<json>, ["~> 1.2.4"])
    s.add_dependency(%q<rest-client>, [">= 1.6.1"])
    s.add_development_dependency('rspec')
  end
end

