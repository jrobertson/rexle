Gem::Specification.new do |s|
  s.name = 'rexle'
  s.version = '0.6.0'
  s.summary = 'rexle'
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('rexleparser')
  s.add_dependency('dynarex-parser')
  s.add_dependency('polyrex-parser')
end
