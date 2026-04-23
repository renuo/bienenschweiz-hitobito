$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your wagon's version:
require 'hitobito_bienenschweiz/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  # rubocop:disable SingleSpaceBeforeFirstArg
  s.name        = 'hitobito_bienenschweiz'
  s.version     = HitobitoBienenschweiz::VERSION
  s.authors     = ['Raphael Nestler']
  s.email       = ['raphael.nestler@renuo.ch']
  # s.homepage    = 'TODO'
  s.summary     = 'Bienenschweiz Hitobito Wagon'
  s.description = 'Bienenschweiz specific Hitobito features'

  s.files = Dir['{app,config,db,lib}/**/*'] + ['Rakefile']
  s.test_files = Dir['test/**/*']
  # rubocop:enable SingleSpaceBeforeFirstArg
end
