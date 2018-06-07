# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','data_correlator','version.rb'])
spec = Gem::Specification.new do |s|
  s.name = 'data_correlator'
  s.version = DataCorrelator::VERSION
  s.author = 'Miguel Diaz'
  s.email = 'mdiaz.git+thor@codescrum.com'
  s.homepage = 'https://codescrum.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Data correlator is an utility built to match data from different sources using custom criteria. Its main use is for data recovery procedures, which need matching information from multiple sources to uncover the true data.'
  s.files = `git ls-files`.split("
")
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','data_correlator.rdoc']
  s.rdoc_options << '--title' << 'data_correlator' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'data_correlator'
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec','3.7.0')
  s.add_development_dependency('spirit_hands')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba')
  s.add_runtime_dependency('gli','2.17.1')
  s.add_runtime_dependency('activesupport','5.2.0')
  s.add_runtime_dependency('virtus','1.0.5')
end
