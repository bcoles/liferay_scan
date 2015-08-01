Gem::Specification.new do |s|
  s.name        = 'LiferayScan'
  s.version     = '0.0.1'
  s.required_ruby_version = ">= 2.0.0"
  s.date        = '2015-08-01'
  s.summary     = 'Liferay scanner'
  s.description = 'A simple remote scanner for Liferay Portal'
  s.license     = 'MIT'
  s.authors     = ["Brendan Coles"]
  s.email       = 'bcoles@gmail.com'
  s.files       = ["lib/LiferayScan.rb", "data/users.txt", "data/names.txt", "data/portlets.txt"]
  s.homepage    = 'https://github.com/bcoles/LiferayScan'
  s.executables << 'LiferayScan'
end
