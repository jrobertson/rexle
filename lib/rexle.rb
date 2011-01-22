#!/usr/bin/ruby

# file: rexle.rb

require 'rexml/document'
require 'rexleparser'
require 'dynarex-parser'
require 'polyrex-parser'
include REXML

module XMLhelper

  def doc_print(children)

    body = scan_print(children).join
    a = self.root.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}
    "<%s%s>%s</%s>" % [self.root.name, a.empty? ? '' : ' ' + a.join(' '), body, self.root.name]
  end

  def doc_pretty_print(children)

    body = pretty_print(children,2).join
    a = self.root.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}
    ind = "\n  "   
    "<%s%s>%s%s%s</%s>" % [self.root.name, a.empty? ? '' : ' ' + a.join(' '), ind, body, "\n", self.root.name]
  end

  def scan_print(nodes)

    nodes.map do |x|
      unless x.name == '![' then
        a = x.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}      
        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))

        out = ["<%s>" % tag]
        out << x.value unless x.value.nil? || x.value.empty?
        out << scan_print(x.children)
        out << "</%s>" % x.name
      else    
        "<![CDATA[%s]]>" % x.value
      end
    end

  end

  def pretty_print(nodes, indent='0')
    indent = indent.to_i
    nodes.map.with_index do |x, i|
      unless x.name == '![' then
        a = x.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}      
        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))

        ind1 = x.children.length > 0 ? ("\n" + '  ' * indent) : ''
        start = i > 0 ? ("\n" + '  ' * (indent - 1)) : ''
        out = ["%s<%s>%s" % [start, tag, ind1]]

        out << x.value.sub(/^[\n\s]+$/,'') unless x.value.nil? || x.value.empty?
        out << pretty_print(x.children, (indent + 1).to_s.clone)
        ind2 = x.children.length > 0 ? ("\n" + '  ' * (indent - 1)) : ''
        out << "%s</%s>" % [ind2, x.name]
      else    
        "<![CDATA[%s]]>" % x.value
      end
    end

  end

end

class Rexle
  include XMLhelper

  def initialize(x=nil)
    super()

    if x then
      procs = {
	      String: proc {|x| parse_string(x)},
	      Array: proc {|x| x},
	      :"REXML::Document" =>  proc {|x| scan_doc x.root}
      }
      a = procs[x.class.to_s.to_sym].call(x)
      @doc = scan_element(*a)      
    end
    
  end

  def xpath(path, &blk)

    # is it a function
    fn_match = path.match(/^(\w+)\(([^\)]+)\)$/)

    #    Array: proc {|x| x.flatten.compact}, 
    if fn_match.nil? then      
      procs = {
        Array: proc {|x| block_given? ? x : x.flatten }, 
        String: proc {|x| x},
        :"Rexle::Element" => proc {|x| [x]}
      }
      bucket = []
      result = @doc.xpath(path, bucket, &blk)

      procs[result.class.to_s.to_sym].call(result)
      
    else
      m, xpath_value = fn_match.captures
      method(m.to_sym).call(xpath_value)
    end

  end

  class Element
    include XMLhelper
    
    attr_accessor :name, :value, :parent
    attr_reader :child_lookup

    def initialize(name=nil, value='', attributes={})
      super()
      @name, @value, @attributes = name, value, attributes
      raise "Element name must not be blank" unless name
      @child_elements = []
      @child_lookup = []
    end

    def xpath(xpath_value, rlist=[], &blk)

      raw_path, raw_condition = xpath_value.sub(/^\/(?!\/)/,'').match(/([^\[]+)(\[[^\]]+\])?/).captures 
      remaining_path = ($').to_s
      a_path = raw_path.split('/')

      condition = raw_condition if a_path.length <= 1

      if raw_path[0,2] == '//' then
        s = a_path[2] || ''
        condition = raw_condition
      elsif raw_path == 'text()' then      
        a_path.shift
        return @value
      else
        attribute = xpath_value[/^attribute::(.*)/,1] 
        return @attributes[attribute] if attribute and @attributes and @attributes.has_key?(attribute)
 
        s = a_path.shift
      end      

      # isolate the xpath to return just the path to the current element
      elmnt_path = s[/^([\w\*]+\[[^\]]+\])|[\/]+{,2}[^\/]+/]
      element_part = elmnt_path[/(^@?[^\[]+)?/,1] if elmnt_path

      if element_part then
        unless element_part[/^@/] then
          element_name = element_part
        else
          condition = element_part
          element_name = nil
        end

      end

      raw_condition = '' if condition

      attr_search = format_condition(condition) if condition and condition.length > 0

      if raw_path[0,2] == '//'
        return_elements = scan_match(self, element_name, attr_search, condition, rlist) 
        return (xpath_value[/text\(\)$/] ? return_elements.map(&:value) : return_elements)
      end

      return_elements = @child_lookup.map.with_index.select do |x|
        x[0][0] == element_name or element_name == '*'
      end
        
      if return_elements.length > 0 then

        if (a_path + [remaining_path]).join.empty? then
          rlist = return_elements.map.with_index {|x,i| filter(x, i+1, attr_search, &blk)}.compact
          rlist = rlist[0] if rlist.length == 1
        else

          rlist << return_elements.map.with_index do |x,i| 
            rtn_element = filter(x, i+1, attr_search){|e| r = e.xpath(a_path.join('/') + raw_condition.to_s + remaining_path, &blk); (r || e) }
            next if rtn_element.nil? or (rtn_element.is_a? Array and rtn_element.empty?)

            if rtn_element.is_a? Array then
              rtn_element
            elsif (rtn_element.is_a? String) || (rtn_element.is_a?(Array) and not(rtn_element[0].is_a? String))
              rtn_element
            elsif rtn_element.is_a? Rexle::Element
              rtn_element
            end
          end
          #
          rlist = rlist.flatten(1) unless rlist.length > 1 and rlist[0].is_a? Array

        end
        rlist.compact! if rlist.is_a? Array

      else

        # strip off the 1st element from the XPath
        new_xpath = xpath_value[/^\/\/\w+\/(.*)/,1]

        if new_xpath then
          self.xpath(new_xpath + raw_condition.to_s + remaining_path, rlist,&blk)
        end
      end

      rlist = rlist.flatten(1) unless not(rlist.is_a? Array) or (rlist.length > 1 and rlist[0].is_a? Array)
      rlist = [rlist] if rlist.is_a? Rexle::Element
      rlist
    end

    def add_element(item)
      @child_lookup << [item.name, item.attributes, item.value]
      @child_elements << item
      # add a reference from this element (the parent) to the child
      item.parent = self
      item
    end    
    
    alias add add_element

    def add_attribute(*x)

      procs = {
        Hash: lambda {|x| x[0] || {}},
        String: lambda {|x| Hash[*x]}
      }  
      h = procs[x[0].class.to_s.to_sym].call(x)

      @attributes.merge! h
    end

    def add_text(s) @value = s; self end
    def attribute(key) @attributes[key] end  
    def attributes() @attributes end    
    def children() @child_elements end    
    def children=(a) @child_elements = a end

    def delete(obj=nil)
      if obj then
        i = @child_elements.index(obj)
        [@child_elements, @child_lookup].each{|x| x.delete_at i} if i
      else
        self.parent.delete self
      end
    end

    def element(s) self.xpath(s).first  end

    def elements(s=nil)
      procs = {
        NilClass: proc {Elements.new(@child_elements)},
        String: proc {|x| @child_elements[x]}
      }
      procs[s.class.to_s.to_sym].call(s)      
    end

    def root() self end

    def text(s='')

      if s.empty? then
        result = @value
      else
        e = self.element(s)
        result = e.value if e
      end
 
      def result.unescape()
        s = self.clone
        %w(&lt; < &gt; > &amp; &).each_slice(2){|x| s.gsub!(*x)}
        s
      end

      result
    end

    def value=(x)
      @value = x.to_s
      a = self.parent.instance_variable_get(:@child_lookup)
      if a then
        i = a.index(a.assoc(@name))      
        a[i][-1] = @value
        self.parent.instance_variable_set(:@child_lookup, a)
      end
    end

    alias text= value=

    def xml(options={})
      o = {pretty: false}.merge(options)
      msg = o[:pretty] == false ? :doc_print : :doc_pretty_print
      method(msg).call(self.children)
    end

    # temp methods

    private

    def scan_print222(nodes)
      out = []
      nodes.each do |x|
        out << "<%s>" % x.name
        out << scan_print(x.children)
        out << "</%s>" % x.name    
      end
      out
    end

    def format_condition(condition)
      #raw_items = condition[1..-1].scan(/\'[^\']*\'|and|or|\d+|[!=]+|[@\w\.\/]+/)
      raw_items = condition[1..-1].scan(/\'[^\']*\'|and|or|\d+|[!=<>]+|position\(\)|[@\w\.\/]+/)

      if raw_items[0][/^\d+$/] then
        return raw_items[0].to_i
      elsif raw_items[0] == 'position()' then
        return "i %s %s" % raw_items[1..-1]
      else

        andor_items = raw_items.map.with_index.select{|x,i| x[/\band\b|\bor\b/]}.map{|x| [x.last, x.last + 1]}.flatten

        indices = [0] + andor_items + [raw_items.length]

        if raw_items[0][0] == '@' then
          raw_items.each{|x| x.gsub!(/^@/,'')}
          cons_items = indices.each_cons(2).map{|x,y| raw_items.slice(x...y)}          

          items = cons_items.map do |x| 

            if x.length >= 3 then
              x[1] = '==' if x[1] == '='
              "h['%s'] %s %s" % x
            else
              x
            end
          end

          return items.join(' ')
        else

          cons_items = indices.each_cons(2).map{|x,y| raw_items.slice(x...y)}
          items = cons_items.map do |x| 

            if x.length >= 3 then
              x[1] = '==' if x[1] == '='
              if x[0] != '.' then
                if x[0][/\//] then
                  path, value = x.values_at(0,-1)

                  "e.xpath('#{path}').first.value == #{value}"
                else
                  "name == '%s' and value %s %s" % [x[0], x[1], x[2]]
                end
              else
                "e.value %s %s" % [x[1], x[2]]
              end
            else
              x
            end
          end

          return items.join(' ')
        end
      end


    end

    def scan_match(nodes, element, attr_search, condition, rlist)

      nodes.children.each.with_index do |x, i|

        h = x.attributes

        if element and not(element.empty?) then
          if x.name == element
            if attr_search then
              rlist << x if h and eval(attr_search)
            else
              rlist << x 
            end
          end
        else

          if condition[/^@/] then
            attribute = condition[/@(.*)/,1]
            if h and h.has_key? attribute then
              rlist << h[attribute]
            end
          else
            rlist << x if h and eval(attr_search)
          end
        end
    
        x.xpath('//' + element.to_s + condition.to_s, rlist) unless x.children.empty?
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
        elsif attr_search[/i\s[<>\=]\s\d+/] and eval(attr_search) then
          block_given? ? blk.call(e) : e
        elsif h and attr_search[/^h\[/] and eval(attr_search)
          block_given? ? blk.call(e) : e
        elsif attr_search[/^name ==/] and \
            e.child_lookup.select{|name, attributes, value| eval(attr_search) }.length > 0
          block_given? ? blk.call(e) : e
        elsif attr_search[/^e\.value/] and eval(attr_search)           
          block_given? ? blk.call(e) : e
        elsif attr_search[/^e\.xpath/] and eval(attr_search)           
          block_given? ? blk.call(e) : e
        end
      else

        block_given? ? blk.call(e) : e
      end

    end

  end # -- end of element --

  class Elements
    def initialize(elements=[])
      super()
      @elements = elements
    end

    def [](i)
      @elements[i-1]
    end
  end # -- end of elements --


  def parse(x=nil)
    
    a = []
    
    if x then
      procs = {
	      String: proc {|x| parse_string(x)},
	      Array: proc {|x| x},
	      :"REXML::Document" =>  proc {|x| scan_doc x.root}
      }
      a = procs[x.class.to_s.to_sym].call(x)
    else    
      a = yield
    end

    @doc = scan_element(*a)
    self
  end

  def add_attribute(x) @doc.attribute(x) end
  def attribute(key) @doc.attribute(key) end
  def attributes() @doc.attributes end
  def add_element(element) @doc.root.add_element(element) end

  alias add add_element

  def delete(xpath) @doc.element(xpath).delete end
  def element(xpath) @doc.element(xpath) end  
  def elements(s=nil) @doc.elements(s) end
  def to_s(options={}) self.xml options end
  def text(xpath) @doc.text(xpath) end
  def root() @doc end

  def write(f) 
    f.write "<?xml version='1.0' encoding='UTF-8'?>\n"  + xml 
  end

  def xml(options={})
    o = {pretty: false}.merge(options)
    msg = o[:pretty] == false ? :doc_print : :doc_pretty_print
    "<?xml version='1.0' encoding='UTF-8'?>\n" +  method(msg).call(self.root.children)
  end

  private

  def parse_string(x)

    # check if the XML string is a dynarex document
    if x[/<summary>/] then

      doc = Document.new("<summary>" + x[/(.*?(<\/?summary>)){2}/m,1])
      recordx_type = doc.root.text('recordx_type')

      if recordx_type then
        procs = {
          'dynarex' => proc {|x| DynarexParser.new(x).to_a},
          'polyrex' => proc {|x| PolyrexParser.new(x).to_a}
        }
        procs[recordx_type].call(x)
      else
        RexleParser.new(x).to_a
      end
    else
      RexleParser.new(x).to_a
    end

  end

  def scan_element(name, value, attributes, *children)
    element = Element.new(name, value, attributes)  
    children.each{|x| element.add_element scan_element(*x)} if children
    return element
  end

  def count(path) @doc.xpath(path).flatten.compact.length end
  def max(path) @doc.xpath(path).map(&:to_i).max end
  
  # scan a rexml doc
  #
  def scan_doc(node)a = rexle.xpath("records/url"){|e| %w(full_url short_url).map{|x| e.text(x)}}
    children = node.elements.map {|child| scan_doc child}
    attributes = node.attributes.inject({}){|r,x| r.merge(Hash[*x])}
    [node.name, node.text.to_s, attributes, *children]
  end
    
end
