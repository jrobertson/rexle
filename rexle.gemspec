Gem::Specification.new do |s|
  s.name = 'rexle'
  s.version = '0.9.74'
  s.summary = 'Rexle is a simple XML parser written purely in Ruby'
  s.files = Dir['lib/**/*.rb']
  s.authors = ['James Robertson']
 
  s.signing_key = '../privatekeys/rexle.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.add_dependency('rexleparser')
  s.add_dependency('dynarex-parser')
  s.add_dependency('polyrex-parser')
  s.add_dependency('rexle-builder') 
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rexle'
end
