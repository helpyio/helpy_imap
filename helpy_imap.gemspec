$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "helpy_imap/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "helpy_imap"
  s.version     = HelpyImap::VERSION
  s.authors     = ["Scott Miller"]
  s.email       = ["scott@helpy.io"]
  s.homepage    = "https://helpy.io"
  s.summary     = "Adds the ability to fetch tickets from an IMAP or POP3 server."
  s.description = "This adds the ability to get email tickets from an IMAP server."
  s.license     = "MIT."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.10"
  s.add_dependency "deface"
  s.add_dependency "mail"
  s.add_dependency "mailman"

  s.add_development_dependency "sqlite3"
end
