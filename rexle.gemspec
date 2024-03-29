Gem::Specification.new do |s|
  s.name = 'rexle'
  s.version = '1.6.0'
  s.summary = 'Rexle is an XML parser written purely in Ruby'
  s.files = Dir['lib/rexle.rb']
  s.authors = ['James Robertson']
  s.signing_key = '../privatekeys/rexle.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.add_runtime_dependency('c32', '~> 0.3', '>=0.3.0')
  s.add_runtime_dependency('rexleparser', '~> 1.0', '>=1.0.0')
  s.add_runtime_dependency('rexle-builder', '~> 1.0', '>=1.0.8')
  s.add_runtime_dependency('rexle-css', '~> 0.2', '>=0.2.0')
  s.add_runtime_dependency('backtrack-xpath', '~> 0.2', '>=0.2.2') 
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/rexle'
  s.required_ruby_version = '>= 2.1.0'
end
