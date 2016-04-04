Gem::Specification.new do |s|
  s.name = 'rexle'
  s.version = '1.3.18'
  s.summary = 'Rexle is an XML parser written purely in Ruby'
  s.files = Dir['lib/**/*.rb']
  s.authors = ['James Robertson']
 
  s.signing_key = '../privatekeys/rexle.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.add_runtime_dependency('rexleparser', '~> 0.7', '>=0.7.0')
  s.add_runtime_dependency('dynarex-parser', '~> 0.3', '>=0.3.0')
  s.add_runtime_dependency('polyrex-parser', '~> 0.3', '>=0.3.4')
  s.add_runtime_dependency('rexle-builder', '~> 0.2', '>=0.2.0') 
  s.add_runtime_dependency('rexle-css', '~> 0.1', '>=0.1.3')
  s.add_runtime_dependency('backtrack-xpath', '~> 0.1', '>=0.1.6') 
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rexle'
  s.required_ruby_version = '>= 2.1.0'
end
