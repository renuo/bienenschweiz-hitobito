$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your wagon's version:
require "hitobito_bienenschweiz/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  # rubocop:disable Style/SingleSpaceBeforeFirstArg
  s.name = "hitobito_bienenschweiz"
  s.version = HitobitoBienenschweiz::VERSION
  s.authors = ["Raphael Nestler"]
  s.email = ["raphael.nestler@renuo.ch"]
  # s.homepage    = 'TODO'
  s.summary = "Bienenschweiz Hitobito Wagon"
  s.description = "Bienenschweiz specific Hitobito features"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
  # to match core Gemfile.lock which is otherwise not considered locally
  s.dependencies << Gem::Dependency.new("haml", "~> 6.3.0")
  s.add_dependency "carrierwave", "~> 3.0"
  s.add_dependency "carrierwave-aws"
  s.add_dependency "mysql2"
  # rubocop:enable Style/SingleSpaceBeforeFirstArg
end
