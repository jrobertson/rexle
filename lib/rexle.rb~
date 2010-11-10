#!/usr/bin/ruby

# file: rexle.rb

require 'rexleparser'

class Rexle

  def initialize(s)
    a = RexleParser.new(s).to_a
    @doc = scan_element(*a)
  end

  def xpath(path)

    # is it a function
    fn_match = path.match(/^(\w+)\(([^\)]+)\)$/)

    if fn_match.nil? then      
      procs = {
        Array: proc {|x| x.flatten.compact}, 
        String: proc {|x| x}
      }
      bucket = []
      result = @doc.xpath(path, bucket)

      procs[result.class.to_s.to_sym].call(result)
      
    else
      m, xpath_value = fn_match.captures
      method(m.to_sym).call(xpath_value)
    end

  end

  class Element
    attr_accessor :name, :value

    def initialize(name=nil, value='', attributes={})
      @name, @value, @attributes = name, value, attributes
      raise "Element name must not be blank" unless name
      @child_elements = []
      @child_lookup = []
    end

    def xpath(xpath_value, rlist=[])

      a = xpath_value.split('/')

      if xpath_value[0,2] == '//' then
        s = a[2]
      elsif xpath_value == 'text()' then      
        a.shift
        return @value
      else
        attribute = xpath_value[/^attribute::(.*)/,1] 
        return @attributes[attribute] if attribute and @attributes and @attributes.has_key?(attribute)
 
        s = a.shift
      end

      element_name, condition = s.match(/(^[^\[]+)(\[[^\]]+\])?/).captures
      
      attr_search = format_attributes(condition) if condition

      return scan_match(self, element_name, attr_search, condition, rlist) if xpath_value[0,2] == '//'

      return_elements = @child_lookup.map.with_index.select do |x|
        x[0][0] == element_name or element_name == '*'
      end
        
      if return_elements.length > 0 then

        if a.empty? then
          rlist = return_elements.map.with_index {|x,i| filter(x, i+1, attr_search)}
        else
          
          rlist << return_elements.map.with_index do |x,i| 
            rtn_element = filter(x, i+1, attr_search){|e| r = e.xpath(a.join('/')); r || e }
            next unless rtn_element 

            if rtn_element.is_a? Array then
              rtn_element.flatten
            elsif (rtn_element.is_a? String) || not(rtn_element[0].is_a? String)
              rtn_element
            end
          end

        end

      else

        # strip off the 1st element from the XPath
        new_xpath = xpath_value[/^\/\/\w+\/(.*)/,1]

        if new_xpath then
          self.xpath(new_xpath, rlist)
        end
      end

      rlist
    end

    def add_element(item)
      @child_lookup << [item.name, item.attributes, item.value]
      @child_elements << item
    end    

    def attributes() @attributes end

    def children() @child_elements end
    
    def children=(a) @child_elements = a end

    def text() @value end

    private

    def scan_print(nodes)
      out = []
      nodes.each do |x|
        out << "<%s>" % x.name
        out << scan_print(x.children)
        out << "</%s>" % x.name    
      end
      out
    end

    def format_attributes(condition)
      raw_items = condition[1..-1].scan(/[\w]+=\'[^\']+\'|and|\d+/)
      
      if raw_items[0][/^\d+$/] then
        return raw_items[0].to_i
      else
        items = raw_items.map do |x| 
          name, value = x.split(/=/)
          if value then
            "h['%s'] == '%s'" % [name,value[1..-2]]
          else
            name
          end
        end
        return items.join(' ')
      end
    end


    def scan_match(nodes, element, attr_search, condition, rlist)
      nodes.children.each.with_index do |x, i|
        if x.name == element
          h = x.attributes
          if attr_search then
            rlist << x if h and eval(attr_search)
          else
            rlist << x 
          end
        end

        x.xpath('//' + element + condition, rlist) unless x.children.empty?
      end
      rlist
    end

    def filter(raw_element, i, attr_search, &blk)

      x = raw_element
      e = @child_elements[x.last]
      h = x[0][1]  # <-- fetch the attributes

      if attr_search then
        if attr_search.is_a? Fixnum then
          block_given? ? blk.call(e) : e if i == attr_search 
        elsif h and eval(attr_search)
          block_given? ? blk.call(e) : e
        end
      else
        block_given? ? blk.call(e) : e
      end

    end

  end # -- end of element --

  def root() @doc end
  def xml()
    body = scan_print(self.root.children).join
    "<%s>%s</%s>" % [self.root.name, body, self.root.name]
  end

  private

  def scan_element(name, value, attributes, *children)
    element = Element.new(name, value, attributes)  
    children.each{|x| element.add_element scan_element(*x)} if children
    return element
  end

  def scan_print(nodes)

    nodes.map do |x|
      a = x.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}      
      tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))

      out = ["<%s>" % tag]
      out << x.value unless x.value.empty?
      out << scan_print(x.children)
      out << "</%s>" % x.name    
    end

  end

  def count(path) @doc.xpath(path).flatten.compact.length end

end