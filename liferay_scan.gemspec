# coding: utf-8
#
# This file is part of LiferayScan
# https://github.com/bcoles/liferay_scan
#

Gem::Specification.new do |s|
  s.name        = 'liferay_scan'
  s.version     = '0.0.2'
  s.required_ruby_version = ">= 3.0.0"
  s.date        = '2025-04-06'
  s.summary     = 'Liferay scanner'
  s.description = 'A simple remote scanner for Liferay Portal'
  s.license     = 'MIT'
  s.authors     = ['Brendan Coles']
  s.email       = 'bcoles@gmail.com'
  s.files       = ['lib/liferay_scan.rb', 'data/users.txt', 'data/names.txt']
  s.homepage    = 'https://github.com/bcoles/liferay_scan'
  s.executables << 'liferay-scan'

  s.add_dependency 'terminal-table', '~> 4.0'
  s.add_dependency 'logger', '~> 1.6'
end
