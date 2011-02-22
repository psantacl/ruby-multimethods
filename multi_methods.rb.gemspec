PKG_VERSION = '1.0.2'
PKG_FILES = Dir['lib/*.rb',
                  'specs/*.rb']

$spec = Gem::Specification.new do |s|
  s.name = 'multi_methods.rb'
  s.version = PKG_VERSION
  s.summary = "General dispatch for ruby"
  s.description = <<EOS
Supports general dispatch using clojure style multi-methods.  This can be used
for anything from basic function overloading to a function dispatch based on arbitrary complexity.
EOS

  s.files = PKG_FILES.to_a

  s.has_rdoc = false
  s.authors = ["Paul Santa Clara"]
  s.email = "kesserich1@gmail.com"
  s.add_development_dependency "rspec"
end

