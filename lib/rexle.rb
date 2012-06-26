#!/usr/bin/ruby

# file: rexle.rb

require 'rexml/document'
require 'rexleparser'
require 'dynarex-parser'
require 'polyrex-parser'
require 'cgi'
include REXML

# modifications:
# 19-Jun-2012: a bug fix for .//*[@class]
# 17-Jun-2012: a couple of new xpath things are supported '.' and '|'
# 15-Apr-2012: bug fix: New element names are typecast as string
# 16-Mar-2012: bug fix: Element names which contain a colon can now be selected
#                in the xpath.
# 22-Feb-2012: bug resolution: Deactivated the PolyrexParser; using RexleParser instead
# 14-Jan-2012: Implemented Rexle::Elements#each
# 21-Dec-2011: Bug fix: xpath modified to allow querying from the actual 
# root rather than the 1st child element from the root
# 04-Sep-2011: Bug fix: xpath will now only return Rexle:elements  when
#                * is used.
# 03-Sep-2011: Implemented deep_clone as well as modifying clone to function 
#                similar to REXML.
# 28-Au-2011: New line characters between elements are now preserved
# 24-Jul-2011: Smybols are used for attribute keys instead of strings now
# 18-Jun-2011: A Rexle document can now be added to another Rexle document 
#                e.g. Rexle.new('<root/>').add Rexle.new "<a>123</a>"

module XMLhelper

  def doc_print(children)

    body = children.empty? ? self.root.value : scan_print(children).join
    a = self.root.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}
    "<%s%s>%s</%s>" % [self.root.name, a.empty? ? '' : ' ' + a.join(' '), body, self.root.name]
    #"<%s%s>%s</%s>" % [self.root.name, a.empty? ? '' : ' ' + a.join(' '), body]
  end

  def doc_pretty_print(children)

    body = children.empty? ? self.value : pretty_print(children,2).join
    a = self.root.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}
    ind = "\n  "   
    "<%s%s>%s%s%s</%s>" % [self.root.name, a.empty? ? '' : ' ' + a.join(' '), ind, body, "\n", self.root.name]
  end

  def scan_print(nodes)

    nodes.map do |x|

      if x.is_a? Rexle::Element then
        if x.name.chr != '!' then
          a = x.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}      
          tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))

          if x.value.length > 0 or x.children.length > 0 then
            out = ["<%s>" % tag]
            out << x.value unless x.value.nil? || x.value.empty?
            out << scan_print(x.children)
            out << "</%s>" % x.name
          else
            out = ["<%s/>" % tag]
          end
        elsif x.name == '!-' then
          "<!--%s-->" % x.value
        else
          "<![CDATA[%s]]>" % x.value      
        end      
      elsif x.is_a? String then
        x
      end
    end

  end

  def pretty_print(nodes, indent='0')
    indent = indent.to_i
    nodes.map.with_index do |x, i|
      if x.is_a? Rexle::Element then
        unless x.name == '![' then
          a = x.attributes.to_a.map{|k,v| "%s='%s'" % [k,v]}      
          a ||= [] 
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
      elsif x.is_a? String then
        x.sub(/^[\n\s]+$/,'')
      end
    end

  end

end

class Rexle
  include XMLhelper

  attr_reader :prefixes

  def initialize(x=nil)
    super()

    # what type of input is it? Is it a string, array, or REXML doc?
    if x then
      procs = {
        String: proc {|x| parse_string(x)},
        Array: proc {|x| x},
        :"REXML::Document" =>  proc {|x| scan_doc x.root}
      }
      
      doc_node = ['doc','',{}]
  

      @a = procs[x.class.to_s.to_sym].call(x)
      @doc = scan_element(*(doc_node << @a))
      
      # fetch the namespaces
      @prefixes = []
      if @doc.root.attributes then

        xmlns = @doc.root.attributes.select {|k,v| k[/^xmlns:/]}
        @prefixes = xmlns.keys.map{|x| x[/\w+$/]}
      end

    end

  end
  
  def xpath(path,  &blk)
    @doc.xpath(path,  &blk)
  end  

  class Element
    include XMLhelper
    
    attr_accessor :name, :value, :parent
    attr_reader :child_lookup
    
    alias original_clone clone

    def initialize(name=nil, value='', attributes={}, rexle=nil)
      @rexle = rexle      
      super()
      @name, @value, @attributes = name.to_s, value, attributes
      raise "Element name must not be blank" unless name
      @child_elements = []
      @child_lookup = []
    end

    def count(path)
      length = query_xpath(path).flatten.compact.length
      length
    end
    
    def max(path) query_xpath(path).flatten.compact.map(&:to_i).max end
      
    def name()

      if @rexle then
        prefix = @rexle.prefixes.find {|x| x == @name[/^(\w+):/,1] } if @rexle.prefixes.is_a? Array
        prefix ? @name.sub(prefix + ':', '') : @name
      else
        @name
      end
    end
    
    def xpath(path, rlist=[], &blk)
      r = filter_xpath(path, rlist=[], &blk)
      r.is_a?(Array) ? r.compact : r      
    end
    
    def filter_xpath(path, rlist=[], &blk)

      # is it a function
      fn_match = path.match(/^(\w+)\(([^\)]+)\)$/)

      #    Array: proc {|x| x.flatten.compact}, 
      if (fn_match and fn_match.captures.first[/^(attribute|@)/]) or fn_match.nil? then 
        procs = {
          Array: proc {|x| block_given? ? x : x.flatten.uniq }, 
          String: proc {|x| x},
          TrueClass: proc{|x| x},
          FalseClass: proc{|x| x},
          :"Rexle::Element" => proc {|x| [x]}
        }
        bucket = []
        raw_results = path.split('|').map do |xp|
          query_xpath(xp, bucket, &blk)
        end

        #results = raw_results.inject(&:+)
        results = raw_results.last
        procs[results.class.to_s.to_sym].call(results) if results
        
      else
        m, xpath_value = fn_match.captures
        method(m.to_sym).call(xpath_value)
      end

    end    
    
    def query_xpath(raw_xpath_value, rlist=[], &blk)

      #remove any pre'fixes
     #@rexle.prefixes.each {|x| xpath_value.sub!(x + ':','') }
      flag_func = false            

      xpath_value = raw_xpath_value #.sub(/^\[/,'*[')
      #xpath_value.sub!(/\.\/(?=[\/])/,'')

      if xpath_value[/^[\w\/]+\s*=.*/] then        
        flag_func = true

        xpath_value.sub!(/^\w+\s*=.*/,'.[\0]')
        xpath_value.sub!(/\/([\w]+\s*=.*)/,'[\1]')

        #result = self.element xpath_value        
        #return [(result.is_a?(Rexle::Element) ? true : false)]
      end

      #xpath_value.sub!(/^attribute::/,'*/attribute::')
      raw_path, raw_condition = xpath_value.sub(/^\.?\/(?!\/)/,'')\
          .match(/([^\[]+)(\[[^\]]+\])?/).captures 

      remaining_path = ($').to_s
      
      r = raw_path[/([^\/]+)(?=\/\/)/,1] 
      if r then
        a_path = raw_path.split(/(?=\/\/)/,2)
      else
        a_path = raw_path.split('/',2)
      end
      
      condition = raw_condition if a_path.length <= 1

      if raw_path[0,2] == '//' then
        s = ''
      elsif raw_path == 'text()'        
        a_path.shift
        return @value
      else

        attribute = xpath_value[/^(attribute::|@)(.*)/,2] 

        return [@attributes[attribute.to_sym]] if attribute and @attributes and @attributes.has_key?(attribute.to_sym)
        s = a_path.shift
      end      

      # isolate the xpath to return just the path to the current element

      elmnt_path = s[/^([\w:\*]+\[[^\]]+\])|[\/]+{,2}[^\/]+/]
      element_part = elmnt_path[/(^@?[^\[]+)?/,1] if elmnt_path
      
      if element_part then
        unless element_part[/^@/] then
          element_name = element_part[/^[\w:\*\.]+/]
        else

          condition = xpath_value[/^\[/] ? xpath_value : element_part
          element_name = nil
        end

      end

      #element_name ||= '*'
      raw_condition = '' if condition
      attr_search = format_condition(condition) if condition and condition.length > 0      
      
      attr_search2 = xpath_value[/^\[(.*)\]$/,1]
      if attr_search2 then        
        r4 = attribute_search(attr_search, self, self.attributes)
        return r4
      end      
      
      return_elements = []

      if raw_path[0,2] == '//' then

        regex = /\[(\d+)\]/
        n = xpath_value[regex,1]
        xpath_value.slice!(regex)
        
        rs = scan_match(self, xpath_value).flatten.compact
        return n ? rs[n.to_i-1] : rs

      elsif (raw_path == '.' or raw_path == self.name) and attr_search.nil? then
        return  [self]
      else

        return_elements = @child_lookup.map.with_index.select do |x|    
          (x[0][0] == element_name || element_name == '.') or \
            (element_name == '*' && x[0].is_a?(Array))
        end

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
        new_xpath = xpath_value[/^\/\/[\w:]+\/(.*)/,1]

        if new_xpath then
          self.xpath(new_xpath + raw_condition.to_s + remaining_path, rlist,&blk)
        end
      end

      rlist = rlist.flatten(1) unless not(rlist.is_a? Array) or (rlist.length > 1 and rlist[0].is_a? Array)
      rlist = [rlist] if rlist.is_a? Rexle::Element
      rlist = (rlist.length > 0 ? true : false) if flag_func == true
      rlist
    end

    def add_element(item)
      if item.is_a? Rexle::Element then
        @child_lookup << [item.name, item.attributes, item.value]
        @child_elements << item
        # add a reference from this element (the parent) to the child
        item.parent = self
        item        
      elsif item.is_a? String then
        @child_lookup << item
        @child_elements << item             
      elsif item.is_a? Rexle then
        self.add_element(item.root)
      end
    end    

    def inspect()
      if self.xml.length > 30 then
      "%s ... </>" % self.xml[/<[^>]+>/]
      else
        self.xml
      end  
    end
    
    alias add add_element

    def add_attribute(*x)

      procs = {
        Hash: lambda {|x| x[0] || {}},
        String: lambda {|x| Hash[*x]},
        Symbol: lambda {|x| Hash[*x]}
      }

      h = procs[x[0].class.to_s.to_sym].call(x)

      @attributes.merge! h
    end

    def add_text(s) @value = s; self end
    
    def attribute(key) 
      key = key.to_sym if key.is_a? String
      @attributes[key].gsub('&lt;','<').gsub('&gt;','>')
    end  
    
    def attributes() @attributes end    
    def children() @child_elements end    
    def children=(a) @child_elements = a end            
    def deep_clone() Rexle.new(self.xml).root end
    def clone() Element.new(@name, @value, @attributes) end
          
    def delete(obj=nil)
      if obj then
        i = @child_elements.index(obj)
        [@child_elements, @child_lookup].each{|x| x.delete_at i} if i
      else
        self.parent.delete self
      end
    end

    def element(s) 
      r = self.xpath(s)
      r.is_a?(Array) ? r.first : r
    end

    def elements(s=nil)
      procs = {
        NilClass: proc {Elements.new(@child_elements.select{|x| x.is_a? Rexle::Element })},
        String: proc {|x| @child_elements[x]}
      }

      procs[s.class.to_s.to_sym].call(s)      
    end

    def doc_root() @rexle.root end
    def each(&blk) @child_elements.each(&blk) end
    def has_elements?() !self.children.empty? end
    def root() self end #@rexle.root end

    def text(s='')

      if s.empty? then
        result = @value
      else
        e = self.element(s)
        result = e.value if e
      end
      result = CGI.unescape_html result.to_s
 
      def result.unescape()
        s = self.clone
        %w(&lt; < &gt; > &amp; & &pos; ').each_slice(2){|x| s.gsub!(*x)}
        s
      end

      result
    end

    def value=(raw_s)

      @value = String.new(raw_s.to_s.clone)
      escape_chars = %w(& &amp; < &lt; > &gt;).each_slice(2).to_a
      escape_chars.each{|x| @value.gsub!(*x)}

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

    alias to_s xml

    private

    def format_condition(condition)

      raw_items = condition[1..-1].scan(/\'[^\']*\'|\"[^\"]*\"|and|or|\d+|[!=<>]+|position\(\)|[@\w\.\/&;]+/)

      if raw_items[0][/^\d+$/] then
        return raw_items[0].to_i
      elsif raw_items[0] == 'position()' then
        rrr = "i %s %s" % [raw_items[1].gsub('&lt;','<').gsub('&gt;','>'), raw_items[-1]]
        return rrr
      else

        andor_items = raw_items.map.with_index.select{|x,i| x[/\band\b|\bor\b/]}.map{|x| [x.last, x.last + 1]}.flatten

        indices = [0] + andor_items + [raw_items.length]

        if raw_items[0][0] == '@' then
          raw_items.each{|x| x.gsub!(/^@/,'')}
          cons_items = indices.each_cons(2).map{|x,y| raw_items.slice(x...y)}          

          items = cons_items.map do |x| 

            if x.length >= 3 then
              x[1] = '==' if x[1] == '='
              "h[:'%s'] %s %s" % x
            else

              x.join[/^(and|or)$/] ? x : ("h[:'%s']" % x)
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
                  "(name == '%s' and value %s '%s')" % [x[0], x[1], x[2].sub(/^['"](.*)['"]$/,'\1')]
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

    
    def scan_match(node, path)

      r = []
      xpath2 = path[2..-1] 
      xpath2.sub!(/^\*\//,'')
      xpath2.sub!(/^\*/,self.name)
      xpath2.sub!(/^\w+/,'').sub!(/^\//,'') if xpath2[/^\w+/] == self.name
      

      r << node.xpath(xpath2)
      r << node.children.map {|n| scan_match(n, path) if n.is_a? Rexle::Element}
      r
    end
    
    def filter(raw_element, i, attr_search, &blk)

      x = raw_element
      e = @child_elements[x.last]
      name, value = e.name, e.value if e.is_a? Rexle::Element

      h = x[0][1]  # <-- fetch the attributes      
      
      if attr_search then
        attribute_search(attr_search,e, h, i, &blk)
      else

        block_given? ? blk.call(e) : e
      end

    end

    def attribute_search(attr_search, e, h, i=nil, &blk)
      if attr_search.is_a? Fixnum then
        block_given? ? blk.call(e) : e if i == attr_search 
      elsif attr_search[/i\s[<>\=]\s\d+/] and eval(attr_search) then
        block_given? ? blk.call(e) : e
      elsif h and attr_search[/^h\[/] and eval(attr_search)
        block_given? ? blk.call(e) : e
      elsif attr_search[/^\(name ==/] and e.child_lookup.select{|name, attributes, value| eval(attr_search) }.length > 0
        block_given? ? blk.call(e) : e
      elsif attr_search[/^\(name ==/] and eval(attr_search) 
        block_given? ? blk.call(e) : e          
      elsif attr_search[/^e\.value/] and eval(attr_search)           
        block_given? ? blk.call(e) : e
      elsif attr_search[/^e\.xpath/] and eval(attr_search)           
        block_given? ? blk.call(e) : e
      end      
    end
  end # -- end of element --

  class Elements
    include Enumerable
    
    def initialize(elements=[])
      super()
      @elements = elements
    end

    def [](i)
      @elements[i-1]
    end
    
    def each(&blk) @elements.each(&blk)  end
    def to_a()     @elements             end
      
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
    doc_node = ['doc','',{}]
    @a = procs[x.class.to_s.to_sym].call(x)
    @doc = scan_element(*(doc_node << @a))
    self
  end

  def add_attribute(x) @doc.attribute(x) end
  def attribute(key) @doc.attribute(key) end
  def attributes() @doc.attributes end
  def add_element(element) @doc.root.add_element(element) end
  def add_text(s) end

  alias add add_element

  def delete(xpath)
    e = @doc.element(xpath)
    e.delete if e
  end
  
  def element(xpath) self.xpath(xpath).first end  
  def elements(s=nil) @doc.elements(s) end
  def name() @doc.root.name end
  def to_a() @a end
  def to_s(options={}) self.xml options end
  def text(xpath) @doc.text(xpath) end
  def root() @doc.children.first end

  def write(f) 
    f.write xml 
  end

  def xml(options={})
    o = {pretty: false, declaration: true}.merge(options)
    msg = o[:pretty] == false ? :doc_print : :doc_pretty_print
    r = ''
    r = "<?xml version='1.0' encoding='UTF-8'?>\n" if o[:declaration] == true
    r << method(msg).call(self.root.children)
    r
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
          'polyrex' => proc {|x| PolyrexParser.new(x).to_a},
          'polyrex' => proc {|x| RexleParser.new(x).to_a}
        }
        procs[recordx_type].call(x)
      else

        RexleParser.new(x).to_a
      end
    else

      RexleParser.new(x).to_a
    end

  end
    
  def scan_element(name, value=nil, attributes=nil, *children)

    element = Element.new(name, value, attributes, self)  

    if children then
      children.each do |x|
        if x.is_a? Array then
          element.add_element scan_element(*x)        
        elsif x.is_a? String
          element.add_element x
        end
      end
    end
    return element
  end

  
  # scan a rexml doc
  #
  def scan_doc(node)
    children = node.elements.map {|child| scan_doc child}
    attributes = node.attributes.inject({}){|r,x| r.merge(Hash[*x])}
    [node.name, node.text.to_s, attributes, *children]
  end
    
end
