#!/usr/bin/ruby

# file: test_rexle.rb
 
require 'testdata'
#require 'rexle'
require '/home/james/learning/ruby/rexle'

testdata = Testdata.new('testdata.xml')

testdata.paths do |path|

  testdata.find_by('value only').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        Rexle.new(xml).xpath(xpath).value 
      end

      expected = output.data('value')
      result == expected
    end

  end

  testdata.find_by('value and attribute').each do |title|
    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        element = Rexle.new(xml).xpath(xpath)
        [element.value, element.attributes.inspect]
      end

      expected = output.data('value','attributes')
      result == expected
    end
  end

  testdata.find_by('multiple values').each do |title|
    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath|
        Rexle.new(xml).xpath(xpath).map(&:value).join(',')
      end

      expected = output.data('value')
      result == expected
    end
  end

  testdata.find_by('function or string').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        Rexle.new(xml).xpath(xpath).to_s
      end

      expected = output.data('value')
      result == expected
    end

  end

  testdata.find_by('multiple strings').each do |title|
    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath|
        Rexle.new(xml).xpath(xpath).join(',')
      end

      expected = output.data('value')
      result == expected
    end
  end

end

puts testdata.passed?
puts testdata.score
puts testdata.instance_variable_get(:@success).map.with_index.select{|x,i| x == false}.map(&:last)


