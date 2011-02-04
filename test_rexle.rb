#!/usr/bin/ruby

# file: test_rexle.rb
 
#require 'testdata'
require '/home/james/learning/ruby/testdata'
#require 'rexle'
require '/home/james/learning/ruby/rexle'
require 'logger'

file = '~/test-ruby/rexle'
this_path = File.expand_path(file)
#FileUtils.mkdir_p this_path

if this_path != Dir.pwd then
  puts "you must run this from script #{this_path}" 
  exit
end

#testdata = Testdata.new(this_path + '/.testdata')
testdata = Testdata.new('/home/james/learning/ruby/testdata.xml', log: false)

testdata.paths do |path|

  testdata.find_by('value only').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).element(xpath).value 
      end

    end
  end

  testdata.find_by('value and attribute').each do |title|
    path.tested? title do 
      def path.test(xml, xpath)
        element = Rexle.new(xml).element(xpath)
        [element.value, element.attributes.inspect]
      end

    end
  end


  testdata.find_by('multiple values').each do |title|

    path.tested? title do 

      def path.test(xml, xpath)
        Rexle.new(xml).xpath(xpath).map(&:value).join(',')
      end

    end
  end

  testdata.find_by('string only').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).element(xpath)
      end

    end

  end

  testdata.find_by('function only').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).xpath(xpath).to_s
      end

    end

  end

  testdata.find_by('multiple strings').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).xpath(xpath).join(',')
      end

    end
  end

  testdata.find_by('name only').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).element(xpath).name 
      end

    end
  end

  testdata.find_by('multiple names').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).xpath(xpath).map(&:name).join(',')
      end

    end
  end

  testdata.find_by('nested xpath').each do |title|

    path.tested? title do

      def path.test(xml, xpath1, xpath2)
        Rexle.new(xml).xpath(xpath1).map {|x| x.xpath(xpath2).map(&:value)}\
          .select{|x| x.length > 0}.join(',')
      end

    end
  end

  testdata.find_by('XML validation').each do |title|

    path.tested? title do

      def path.test(xml)
        out = Rexle.new(xml).xml
        puts 'out : ' + out.to_s
        out
      end

    end
  end


  testdata.find_by('attribute only').each do |title|

    path.tested? title do

      def path.test(xml, xpath, name)
        Rexle.new(xml).element(xpath).attributes[name]
      end

    end
  end

  testdata.find_by('xpath block').each do |title|

    path.tested? title do

      def path.test(xml, xpath, block_fields)
        r = Rexle.new(xml).xpath("records/url") do |e| 
          block_fields.split(/\s/).map{|x| e.text(x)}
        end
        r.inspect
      end

    end
  end

  testdata.find_by('nil only').each do |title|

    path.tested? title do

      def path.test(xml, xpath)
        Rexle.new(xml).element(xpath)
      end

    end
  end

  testdata.find_by('pretty XML output').each do |title|

    path.tested? title do

      def path.test(xml)
        Rexle.new(xml).xml pretty: true
      end

    end
  end

  path.tested? 'return XML from a node' do

    def path.test(xml, xpath)
      Rexle.new(xml).element(xpath).xml
    end

  end

  path.tested? 'auto escape and unescaping text' do

    def path.test(xml, element, value)

      rexle = Rexle.new(xml)
      rexle.element(element).text = value

      escaped = rexle.xml
      unescaped = rexle.element(element).text.unescape
      log = Logger.new('escape.log')
      log.debug 'escaped : ' + escaped
      log.debug 'unescaped : ' + unescaped
      [escaped, unescaped]
    end

  end

end
puts 'fun'

puts testdata.passed?
puts testdata.score
puts testdata.summary.inspect
#puts testdata.success.inspect
puts 'finished'
