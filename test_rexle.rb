#!/usr/bin/ruby

# file: test_rexle.rb
 
require 'testdata'
require 'rexle'
#require '/home/james/learning/ruby/rexle'

testdata = Testdata.new('testdata.xml')

testdata.paths do |path|

  testdata.find_by('value only').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        Rexle.new(xml).xpath(xpath).first.value 
      end

      expected = output.data('value')
      result == expected
    end

  end

  testdata.find_by('value and attribute').each do |title|
    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        element = Rexle.new(xml).xpath(xpath).first
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

  testdata.find_by('string ony').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        r = Rexle.new(xml).xpath(xpath).first
        puts r.inspect
        r
      end

      expected = output.data('value')
      result == expected
    end

  end

  testdata.find_by('function only').each do |title|

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

  testdata.find_by('name only').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        Rexle.new(xml).xpath(xpath).first.name 
      end

      expected = output.data('name')
      result == expected
    end

  end

  testdata.find_by('multiple names').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath') do |xml, xpath| 
        Rexle.new(xml).xpath(xpath).map(&:name).join(',')
      end

      expected = output.data('names')
      result == expected
    end

  end

  testdata.find_by('nested xpath').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml','xpath', 'inner_xpath') do |xml, xpath1, xpath2| 
        Rexle.new(xml).xpath(xpath1).map {|x| x.xpath(xpath2).map(&:value)}\
          .select{|x| x.length > 0}.join(',')
      end

      expected = output.data('names')
      result == expected
    end
  end

  testdata.find_by('XML validation').each do |title|

    path.tested? title do |input, output|
      result = input.data('xml') {|xml| Rexle.new(xml).xml}

      expected = output.data('xml')
      result == expected
    end
  end

end

puts testdata.passed?
puts testdata.score
puts testdata.instance_variable_get(:@success).map.with_index.select{|x,i| x == false}.map(&:last)


