#!/usr/bin/ruby

# file: rexle.rb

class Rexle

  def initialize(s)
    @doc = scan_element(s.split(//))    
  end

  def xpath(path)
    @doc.xpath path
  end

  class Element
    attr_accessor :name, :value

    def initialize(name=nil, value='', attributes={})
      @name, @value, @attributes = name, value, attributes
      raise "Element name must not be blank" unless name
      @child_elements = []
      @child_lookup = {}
    end

    def children()
      @child_elements
    end
    
    def children=(a)
      @child_elements = a
    end

    def add_element(item)
      @child_lookup[item.name] = item.value
      @child_elements << item
    end

    def xpath(xpath_value)

      a = xpath_value.split('/')
      element_name = a.shift

      index = @child_lookup.keys.index(element_name)
      if index then
        if a.empty? then
          @child_elements[index]
        else
          @child_elements[index].xpath a.join
        end
      end
    end

    def attributes()
      @attributes
    end

  end

  def scan_element(a)

    a.shift until a[0] == '<' and a[1] != '/' or a.length < 1

    if a.length > 1 then
      a.shift

      name = ''
      name << a.shift
      name << a.shift while a[0] != ' ' and a[0] != '>'

      if name then

        a.shift until a[0] = '>'
        raw_values = ''
        a.shift
        raw_values << a.shift until a[0] == '<'

        value = raw_values

        if raw_values.length > 0 then
          match_found = raw_values.match(/(.*)>([^>]+$)/)
          if match_found then
            raw_attributes, value = match_found.captures
            attributes = raw_attributes.split(/\s/).inject({}) do |r, x| 
              attr_name, val = x.split(/=/) 
              r.merge(attr_name => val[1..-2])
            end
          end
        end

        element = Element.new(name, value, attributes)

        tag = a[0, name.length + 3].join

        if a.length > 0 then
          children = true
          children = false if tag == "</%s>" % name

          if children == true then
            r = scan_element(a)
            element.add_element(r) if r

            # capture siblings
            a.slice!(0, name.length + 3) if a[0, name.length + 3].join == "</%s>" % name

            (r = scan_element(a); element.add_element r if r) until (a[0, name.length + 3].join == "</%s>" % [name]) or a.length < 2
          else
            #check for its end tag
            a.slice!(0, name.length + 3) if a[0, name.length + 3].join == "</%s>" % name
          end

        end

        element

      end
    end
  end

end
