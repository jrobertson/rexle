#!/usr/bin/ruby

# file: rexle.rb

class Rexle

  def initialize(s)
    @doc = scan_element(s.split(//))    
  end

  def xpath(path)
    @doc.xpath(path).flatten.compact
  end

  class Element
    attr_accessor :name, :value

    def initialize(name=nil, value='', attributes={})
      @name, @value, @attributes = name, value, attributes
      raise "Element name must not be blank" unless name
      @child_elements = []
      @child_lookup = []
    end

    def children()
      @child_elements
    end
    
    def children=(a)
      @child_elements = a
    end

    def add_element(item)
      @child_lookup << [item.name, item.attributes, item.value]
      @child_elements << item
    end    

    def xpath(xpath_value)

      a = xpath_value.split('/')

      if xpath_value[0,2] == '//' then
        s = a[2]
      else
        s = a.shift
      end

      element_name, condition = s.split(/\[/)
      
      if condition then
        raw_items = condition.scan(/[\w]+=\'[^\']+\'|and/)

        items = raw_items.map do |x| 
          name, value = x.split(/=/)
          if value then
            "h['%s'] == '%s'" % [name,value[1..-2]]
          else
            name
          end
        end

        attr_search = items.join(' ')

      end

      wildcard = element_name[0,2] == '//'
      return_elements = @child_lookup.map.with_index.select {|x| x[0][0] == element_name}
        
      if return_elements.length > 0 then
        if a.empty? then
          return_elements.map {|x| filter(x, attr_search)}
        else
          return_elements.map {|x| filter(x, attr_search){|e| r = e.xpath a.join('/'); r || e }}
        end
      else
        # strip off the 1st element from the XPath
        new_xpath = xpath_value[/^\/\/\w+\/(.*)/,1]
        if new_xpath then
          self.xpath new_xpath
        end
      end
    end

    def attributes()
      @attributes
    end


    def filter(raw_element, attr_search, &blk)

      x = raw_element
      e = @child_elements[x.last]

      if attr_search then
        h = x[0][1]            
        block_given? ? blk.call(e) : e if h and eval(attr_search)
      else
        block_given? ? blk.call(e) : e
      end
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
