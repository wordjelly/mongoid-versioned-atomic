$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mongoid_versioned_atomic/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mongoid_versioned_atomic"
  s.version     = MongoidVersionedAtomic::VERSION
  s.authors     = ["greatmanta111"]
  s.email       = ["bhargav.r.raut@gmail.com"]
  s.homepage    = "http://www.github.com/wordjelly"
  s.summary     = "Adds atomic versioning support to mongoid"
  s.description = "coming soon."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rake"
  s.add_dependency "rails"
  s.add_dependency "mongoid"
  s.add_dependency "mongoid-paperclip"
  #s.add_dependency "aws-sdk"

end
