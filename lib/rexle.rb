#!/usr/bin/env ruby

# file: rexle.rb

require 'rexleparser'
require 'dynarex-parser'
require 'polyrex-parser'
require 'rexle-css'
require 'cgi'


# modifications:

# 07-Feb-2015: Implemented XPath function last() e.g. 
#                                       doc.root.xpath('records/item[last()]')
# 05-Feb=2015: bug fix: 
#                  Rexle::Element#texts now transforms all items to a String
# 04-Feb-2015: An xpath containing text() now calls texts() to 
#              return all strings within that element
# 03-Feb-2015: feature: Rexle::Element#text now includes the unescape method
# 30-Jan-2015: Rexle::Element#texts now returns the values of 
#                CData elements as well as strings
# 29-Jan-2015: Removed code references to REXML, as it was no longer needed.
#              feature: Implemented Rexle::Element#cdatas. A CData element is 
#                       now created from the parsing stage.
# 26-Jan-2015: bug fix: An element containing a nil value is now treated as an 
#                       empty string when quering with an XPath
# 25-Dec-2014: bug fix: script tag is now formatted with expected attributes
# 21-Dec-2014: HTML related: A script tag will no longer be a self-closing tag.
# 20-Dec-2014: bug fix: Fixes an uncommon XPath selection. 
#  see http://www.jamesrobertson.eu/bugtracker/2014/dec/18/xpath-returns-an-empty-list.html
# 07-Dec-2014: feature: The Rexle::Element#Css() parameter can now contain 
#                       multiple css paths within the string e.g. '.abc, div'
# 30-Nov-2014: feature: XPath now supports parent (..) traversal e.g. b/../b2
# 21-Nov-2014: feature: Added at_css() to select a single element
# 27-Oct-2014: bug fix: Now Checks for an array instead of a string when 
#                       outputting xml attribute values to get 
#                       around nil values
# 26-Oct-2014: bug fix: XML output containing a class attribute, 
#                       now appears as a string.   Empty nodes are 
#                       now displayed as self-closing tags. 
#                       An XPath containing a @class attribute is now 
#                       first validated against the element attribute existence
#                       Rexle::Element#attribute now checks the attributes type
# 21-Oct-2014: partial feature: An Xpath containing //preceding-sibling and 
#                       //following-sibling now works
# 19-Oct-2014: feature: An XPath containing the attribute @class is 
#              now treated as a type of CSS selector storage area
#              feature: Implemented Rexle::Element#previous_element and
#                       Rexle::Element#next_element

# 13-Oct-2014: feature: Implemented Rexle#clone
# 12-Oct-2014: feature: Implemented CSS style element selection
# 27-Sep-2014: bug fix: ELement values are now explicitly transformed to string
# 16-Sep-2014: Feature: Impelemented Rexle::Element#each_recursive
# 07-Aug-2014: feature: Rexle::CData can now be used to create CDATA
# 12-Jul-2014: XPath with a single element condition now works e.g. b[c]
# 07-Jun-2014: bug fix: An XPath nested within an XPath (using a selector) 
#                       should now wok properly e.g. record/abc[item/xyz="red"]
# 04-Jun-2014: bug fix: If XPath contains /text(), only valid 
#                       text elements are returned
# 03-Jun-2014: bug fix: Text elements are now nil by default
# 01-Jun-2014: bug fix: XPath elements separated by a pipe '|' are now 
#                       stripped of white space
# 20-May-2014: feature: XPath Descendants after the element (or without
#                       the element) are now supported
# 02-Apr-2014: bug fix: Rexle::Element#each now returns the children, 
#                       including the 1st text element
# 24-Mar-2014: minor bug fix: A blank line is no longer inserted at the 
#              top of the XML document
# 14-Mar-2014: bug fix: An XML processing instruction will now only be 
#                       display if declaration = true
# 12-Mar-2014: bug fix: Duplicate processing instruction bug fixed
# 17-Jan-2014: bug fix: Rexle::Element to_a now returns all child elements
# 31-Dec-2013: feature: now supports processing instructions
# 18-Dec-2013: feature fix: the result of text() is no longer unescaped
# 13-Dec-2013: bug fix: elements with dashes can now be queried
# 14-Nov-2013: feature: Implemented method content() to output XML as 
#                unescaped plain text
# 08-Nov-2013: An element will now only be deleted if it has a parent
# 05-Nov-2013: If a node is added to the document which already exists in the
#                 node, it will be moved accordingly.
# 05-Nov02013: XPath bug fix: recursive selector with conditional parent now 
#                returns the correct child e.g. //b[2]/c
# 10-Oct-2013: bug fix: child elements which have the same name as their parent 
#                are now select correctly through XPath
# 22-sep-2013: feature: remove() is now an alias of delete()
# 30-jul-2013: feature: Rexle::Element#xml now accepts an xpath
# 25-jun-2013: bug fix: doc.root.delete(xpath) fixed
# 10-Nov-2012: Elements can now be added starting from an empty document
# 06-Nov-2012: additional xpath predicate now implemented e.g.
#               fun/. > 200 => [false, false, true, true]
# 21-Oct-2012: xpath predicate now implemented e.g. fun/@id='4' => true
# 20-Oct-2012: feature: added Rexle::Element#texts which is the equivalent
#                 of REXML::Element#texts
#              feature: Rexle::Element#add_text is now the equivalent of 
#                 REXML::Element#add_text                  
# 10-Sep-2012: bug fix: Removed code from method pretty_print in order to
#                 get the XML displayed properly
# 23-Aug-2012: feature: implemented xpath function contains()
# 17-Aug-2012: bug fix: pretty print now ignores text containing empty space
# 16-Aug-2012: the current element's text (if its not empty) is now returned 
#                from its children method
# 15-Aug-2012: feature: xpath containing child:: now supported
# 13-Aug-2012: bug fix: xpath can now handle the name() function
# 11-Aug-2012: bug fix: separated the max() method from 1 line into 3 
#                and that fixed it
# 08-Aug-2012: feature: added Element#insert_before and Element#insert_after
# 19-Jul-2012: Changed children to elements where appropriate
# 15-Jul-2012: bug fix: self.root.value is no longer appended
#                 to the body if there are no child elements
# 19-Jun-2012: a bug fix for .//*[@class]
# 17-Jun-2012: a couple of new xpath things are supported '.' and '|'
# 15-Apr-2012: bug fix: New element names are typecast as string
# 16-Mar-2012: bug fix: Element names which contain a colon can now be selected
#                in the xpath.
# 22-Feb-2012: bug resolution: Deactivated the PolyrexParser; using RexleParser instead
# 14-Jan-2012: Implemented Rexle::Elements#each
# 21-Dec-2011: Bug fix: xpath modified to allow querying from the actual 
# root rather than the 1st child element from the root

module XMLhelper

  def doc_print(children, declaration=true)
    
    body = (children.nil? or children.empty? or children.is_an_empty_string? ) ? '' : scan_print(children).join

    a = self.root.attributes.to_a.map do |k,v|
      "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
    end

    xml = "<%s%s>%s</%s>" % [self.root.name, a.empty? ? '' : \
      ' ' + a.join(' '), body, self.root.name]

    if self.instructions and declaration then
      processing_instructions() + xml
    else 
      xml
    end
  end

  def doc_pretty_print(children, declaration=true)

    body = pretty_print(children,2).join

    a = self.root.attributes.to_a.map do |k,v| 
      "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
    end
    
    ind = "\n  "   
    xml = "<%s%s>%s%s%s</%s>" % [self.root.name, a.empty? ? '' : \
      ' ' + a.join(' '), ind, body, "\n", self.root.name]

    if self.instructions and declaration then
      processing_instructions("\n") + "\n" + xml
    else 
      xml
    end
  end

  def processing_instructions(s='')
    self.instructions.map do |instruction|
      "<?%s?>" % instruction.join(' ') 
    end.join s
  end

  def scan_print(nodes)

    nodes.map do |x|

      if x.is_a? Rexle::Element then
        
        a = x.attributes.to_a.map do |k,v| 
          "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
        end

        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))

        if  (x.children and x.children.length > 0 \
            and not x.children.is_an_empty_string?) or x.name == 'script' then

          out = ["<%s>" % tag]
          #out << x.value unless x.value.nil? || x.value.empty?
          out << scan_print(x.children)
          out << "</%s>" % x.name
        else
          out = ["<%s/>" % tag]
        end
      
      elsif x.is_a? String then  x
      elsif x.is_a? Rexle::CData then x.print        
      elsif x.is_a? Rexle::Comment then x.print        
        
      end
    end

  end
  
  def scan_to_a(nodes)

    nodes.inject([]) do |r,x|

      if x.is_a? Rexle::Element then

        a = [x.name, x.attributes, x.value]

        (a.concat(scan_to_a(x.children))) if x.children.length > 1
        r << a
      elsif x.is_a? String then

        r << x
      end

    end

  end
  


  def pretty_print(nodes, indent='0')

    indent = indent.to_i
    return '' unless nodes

    nodes.select(){|x| x.to_s.strip.length > 0}
        .map.with_index do |x, i|

      if x.is_a? Rexle::Element then
        
        #return ["<%s/>" % x.name] if x.value = ''
        a = x.attributes.to_a.map do |k,v| 
          "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
        end
        a ||= [] 
        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))
        start = i > 0 ? ("\n" + '  ' * (indent - 1)) : ''          
        
        if (x.value and x.value.length > 0) \
            or (x.children and x.children.length > 0 \
            and not x.children.is_an_empty_string?) or x.name == 'script'  then

          ind1 = (x.children and x.children.grep(Rexle::Element).length > 0) ? 
            ("\n" + '  ' * indent) : ''
            
          out = ["%s<%s>%s" % [start, tag, ind1]]
          out << pretty_print(x.children, (indent + 1).to_s.clone) 
          ind2 = (ind1 and ind1.length > 0) ? ("\n" + '  ' * (indent - 1)) : ''
          out << "%s</%s>" % [ind2, x.name]            
        else
          out = ["%s<%s/>" % [start, tag]]
        end


      elsif x.is_a? String then  x.sub(/^[\n\s]+$/,'')
      elsif x.is_a? Rexle::CData then x.print        
      elsif x.is_a? Rexle::Comment then x.print           
      end
    end

  end

end

class Rexle
  include XMLhelper

  attr_reader :prefixes, :doctype
  attr_accessor :instructions
  
  def initialize(x=nil)

    super()

    @instructions = [["xml", "version='1.0' encoding='UTF-8'"]] 
    @doctype = :xml

    # what type of input is it? Is it a string, array, or REXML doc?
    if x then
      procs = {
        String: proc {|x| parse_string(x)},
        Array: proc {|x| x}
      }
      
      doc_node = ['doc',{}]
  

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
  
  def clone()
    Rexle.new self.to_a
  end
  
  def at_css(selector)
    @doc.root.element RexleCSS.new(selector).to_xpath
  end  
  
  def css(selector)
    selector.split(',').flat_map{|x| @doc.root.xpath RexleCSS.new(x).to_xpath}
  end
  
  def xpath(path,  &blk)
    @doc.xpath(path,  &blk)
  end  

  class Element
    include XMLhelper
    
    attr_accessor :name, :value, :parent
    attr_reader :child_elements, :doc_id, :instructions
    
    alias original_clone clone

    def initialize(name=nil, value: nil, attributes: {}, rexle: nil)

      @rexle = rexle      
      super()

      @name, @attributes = name.to_s, attributes

      raise "Element name must not be blank" unless name
      @child_elements = []
      self.add_text value if value

    end
    
    def cdata?()
      self.is_a? CData
    end

    def contains(raw_args)
      path, raw_val = raw_args.split(',',2)
      val = raw_val.strip[/^["']?.*["']?$/]      
      
      anode = query_xpath(path)
      return unless anode
      a = scan_contents(anode.first)
     
      [a.grep(/#{val}/).length > 0]
    end    
    
    def count(path)
      length = query_xpath(path).flatten.compact.length
      length
    end

    def at_css(selector)
      self.root.element RexleCSS.new(selector).to_xpath
    end 
    
    def css(selector)

      selector.split(',')\
                  .flat_map{|x| self.root.xpath RexleCSS.new(x).to_xpath}
    end    
    
    def max(path) 
      a = query_xpath(path).flatten.select{|x| x.is_a? String}.map(&:to_i)
      a.max 
    end
      
    def name()
      if @rexle then
        prefix = @rexle.prefixes.find {|x| x == @name[/^(\w+):/,1] } if @rexle.prefixes.is_a? Array
        prefix ? @name.sub(prefix + ':', '') : @name
      else
        @name
      end
    end
    
    def next_element()      

      id  = self.object_id
      a = self.parent.child_elements      
      i = a.index {|x| x.object_id == id} + 1
      
      a[i] if  i < a.length
        
    end
    
    alias next_sibling next_element
    
    def previous_element()      
      
      id  = self.object_id
      a = self.parent.child_elements      
      i = a.index {|x| x.object_id == id} - 1
      
      a[i] if  i >= 0 

    end
    
    alias previous_sibling previous_element
    
    def xpath(path, rlist=[], &blk)

      #return if path[/^(?:preceding|following)-sibling/]
      r = filter_xpath(path, rlist=[], &blk)
      r.is_a?(Array) ? r.compact : r      
    end
    
    def filter_xpath(path, rlist=[], &blk)
      
      # is it a function
      fn_match = path.match(/^(\w+)\(["']?([^\)]*)["']?\)(?:\[(.*)\])?$/)
      end_fn_match = path.slice!(/\[\w+\(\)\]$/)
      
      if end_fn_match then
        
        m = end_fn_match[1..-4]
        [method(m.to_sym).call(xpath path)]
      
      elsif (fn_match and fn_match.captures.first[/^(attribute|@)/]) or fn_match.nil? then 

        procs = {
          #jr061012 Array: proc {|x| block_given? ? x : x.flatten.uniq },
          Array: proc { |x| 
            if block_given? then 
              x.flatten(1) 
            else
              rs = x.flatten
              rs.any?{|x| x == true or x == false} ? rs : rs.uniq(&:object_id) 
            end
          }, 
         String: proc {|x| x},
          Hash: proc {|x| x},
          TrueClass: proc{|x| x},
          FalseClass: proc{|x| x},
          :"Rexle::Element" => proc {|x| [x]}
        }
        bucket = []
        raw_results = path.split('|').map do |xp|

          query_xpath(xp.strip, bucket, &blk)         
        end

        results = raw_results

        procs[results.class.to_s.to_sym].call(results) if results              
        
      else

        m, xpath_value, index = fn_match.captures        
        
        if m == 'text' then
          a = texts()
          return index ? a[index.to_i - 1].to_s : a
        end
        
        xpath_value.empty? ? method(m.to_sym).call : method(m.to_sym).call(xpath_value) 
      end

    end    
    
    def query_xpath(raw_xpath_value, rlist=[], &blk)

      #remove any pre'fixes
     #@rexle.prefixes.each {|x| xpath_value.sub!(x + ':','') }
      flag_func = false            

      xpath_value = raw_xpath_value.sub('child::','./')
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

      r = raw_path[/^([^\/]+)(?=\/\/)/,1] 
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
        #return @value
        return self.texts
      else

        attribute = xpath_value[/^(attribute::|@)(.*)/,2] 
  
        return @attributes  if attribute == '*'
        return [@attributes[attribute.to_sym]] if attribute and @attributes and @attributes.has_key?(attribute.to_sym)
        s = a_path.shift
      end      

      # isolate the xpath to return just the path to the current element

      elmnt_path = s[/^([\w:\-\*]+\[[^\]]+\])|[\/]+{,2}[^\/]+/]
      element_part = elmnt_path[/(^@?[^\[]+)?/,1] if elmnt_path

      if element_part then

        unless element_part[/^(@|[@\.\w]+[\s=])/] then
          element_name = element_part[/^[\w:\-\*\.]+/]

        else
          if xpath_value[/^\[/] then
            condition = xpath_value
            element_name = nil
          else
            condition = element_part

            attr_search = format_condition('[' + condition + ']')
            return [attribute_search(attr_search, self, self.attributes) != nil]            
          end

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

        regex = /\[(\d+)\]$/
        n = xpath_value[regex,1]
        xpath_value.slice!(regex)

        rs = scan_match(self, xpath_value).flatten.compact
        return n ? rs[n.to_i-1] : rs

      else

        if element_name.is_a? String then
          ename, raw_selector = (element_name.split('::',2)).reverse
          
          selector = case raw_selector
            when 'following-sibling' then 1
            when 'preceding-sibling' then -1
          end
          
        else
          ename = element_name
        end        

        if ename != '..' then

          return_elements = @child_elements.map.with_index.select do |x, i|
            
            next unless x.is_a? Rexle::Element

            (x.name == ename || ename == '.') or  (ename == '*')
          end
          
          if selector then
            ne = return_elements.inject([]) do |r,x| 
              i = x.last + selector
              if i >= 0 then
                r << i
              else
                r
              end
            end

            return_elements = ne.map {|x| [@child_elements[x], x] if x}
          end
        else
                    
          remaining_xpath = raw_path[/\.\.\/(.*)/,1]
          # select the parent element

          r2 =  self.parent.xpath(remaining_xpath)

          return r2
          
        end
      end


      if return_elements.length > 0 then

        if (a_path + [remaining_path]).join.empty? then

          rlist = return_elements.map.with_index {|x,i| filter(x, i+1, attr_search, &blk)}.compact          
          rlist = rlist[0] if rlist.length == 1

        else

          rlist << return_elements.map.with_index do |x,i| 

            rtn_element = filter(x, i+1, attr_search) do |e| 

              r = e.xpath(a_path.join('/') + raw_condition.to_s \
                    + remaining_path, &blk)
              r
              #(r || e) 
            end

            next if rtn_element.nil? or (rtn_element.is_a? Array and rtn_element.empty?)

            if rtn_element.is_a? Hash then
              rtn_element
            elsif rtn_element.is_a? Array then
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
        new_xpath = xpath_value[/^\/\/[\w:\-]+\/(.*)/,1]

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

      if item.is_a? String then
        @child_elements << item

      elsif item.is_a? Rexle::CData then
        @child_elements << item        
      elsif item.is_a? Rexle::Element then

        @child_elements << item
        # add a reference from this element (the parent) to the child
        item.parent = self
        item        
          
      elsif item.is_a? Rexle then
        self.add_element(item.root)
      end

    end 

    def add(item)   

      if item.is_a? Rexle::Element then

        if self.doc_id == item.doc_id then

          new_item = item.deep_clone
          add_element new_item
          item.delete
          item = new_item
          new_item
        else
          add_element item
        end
      else
        add_element item
      end

    end

    def inspect()
      if self.xml.length > 30 then
      "%s ... </>" % self.xml[/<[^>]+>/]
      else
        self.xml
      end  
    end
    
    #alias add add_element

    def add_attribute(*x)

      procs = {
        Hash: lambda {|x| x[0] || {}},
        String: lambda {|x| Hash[*x]},
        Symbol: lambda {|x| Hash[*x]}
      }

      h = procs[x[0].class.to_s.to_sym].call(x)

      @attributes.merge! h
    end

    def add_text(s)
      self.value = (self.value || '') + s.to_s
      self 
    end
    
    def attribute(key) 
      
      key = key.to_sym if key.is_a? String
      
      if @attributes[key].is_a? String then
        @attributes[key].gsub('&lt;','<').gsub('&gt;','>') 
      else
        @attributes[key]
      end
    end  
    
    def attributes() @attributes end    
      
    def cdatas()
      self.children.inject([]){|r,x| x.is_a?(Rexle::CData) ? r << x.to_s : r }
    end
      
    def children()

      #return unless @value
      #r = (@value.to_s.empty? ? [] : [@value])  + @child_elements
      r =  @child_elements
      def r.is_an_empty_string?()
        self.length == 1 and self.first == ''
      end      
      
      return r
    end 

    #alias child_elements children

    def children=(a)   @child_elements = a if a.is_a? Array  end
    
    def deep_clone() Rexle.new(self.xml).root end
      
    def clone() 
      Element.new(@name, attributes: @attributes) 
    end
          
    def delete(obj=nil)

      if obj then

        if obj.is_a? String then
          e = self.element obj
          e.delete if e
        else

          #jr010215 [@child_elements, @child_lookup].each{|x| x.delete_at i} if i
          i = @child_elements.index(obj)
          [@child_elements].each{|x| x.delete_at i} if i          
        end
      else

        self.parent.delete(self) if self.parent
      end
    end

    alias remove delete

    def element(s)
      r = self.xpath(s)
      r.is_a?(Array) ? r.first : r
    end

    def elements(s=nil)
      procs = {
        NilClass: proc {Elements.new(@child_elements.select{|x| x.kind_of? Rexle::Element })},
        String: proc {|x| @child_elements[x]}
      }

      procs[s.class.to_s.to_sym].call(s)      
    end

    def doc_root() @rexle.root                                  end
    def each(&blk)    self.children.each(&blk)                  end
    def each_recursive(&blk) recursive_scan(self.children,&blk) end
    alias traverse each_recursive
    def has_elements?() !self.elements.empty?                   end    
    def insert_after(node)   insert(node, 1)                    end          
    def insert_before(node)  insert(node)                       end
    def last(a) a.last                                          end
    def map(&blk)    self.children.map(&blk)                    end        
    def root() self                                             end 

    def text(s='')      

      return @child_elements.first if s.empty?
      e = self.element(s)
      e.text if e
    end
    
    def texts()

     r = @child_elements.select do |x|
        x.respond_to? :to_s
      end
      
      r.map do |x|
        def x.unescape()
          s = self.to_s.clone
          %w(&lt; < &gt; > &amp; & &pos; ').each_slice(2){|x| s.gsub!(*x)}
          s
        end            
      end
      
      return r
    end

    def value()
      
      r = @child_elements.first
      
      def r.unescape()
        s = self.clone
        %w(&lt; < &gt; > &amp; & &pos; ').each_slice(2){|x| s.gsub!(*x)}
        s
      end     
      
      return r
    end
        
    def value=(raw_s)

      #@value = String.new(raw_s.to_s.clone)
      val = String.new(raw_s.to_s.clone)
      
      escape_chars = %w(& &amp; < &lt; > &gt;).each_slice(2).to_a
      escape_chars.each{|x| val.gsub!(*x)}
=begin
      a = self.parent.instance_variable_get(:@child_lookup)
      
      if a then
        i = a.index(a.assoc(@name))      
        a[i][-1] = val
        self.parent.instance_variable_set(:@child_lookup, a)
      end
=end      
      t = val

      @child_elements.any? ? @child_elements[0] = t : @child_elements << t
    end

    alias text= value=
        
    def to_a()
      [self.name, self.attributes, self.value, *scan_to_a(self.children)]
    end

    def xml(options={})
      h = {
        Hash: lambda {|x|
          o = {pretty: false}.merge(x)
          msg = o[:pretty] == false ? :doc_print : :doc_pretty_print
          method(msg).call(self.children)
        },
        String: lambda {|x| 
          r = self.element(x)
          r ? r.xml : ''
        }
      }
      h[options.class.to_s.to_sym].call options
    end

    def content(options={})
      CGI.unescapeHTML(xml(options))
    end

    alias to_s xml

    private
    
    def insert(node,offset=0)

      i = parent.child_elements.index(self)
      return unless i

      parent.child_elements.insert(i+offset, node)
      parent.child_lookup.insert(i+offset, [node.name, node.attributes, node.value])          

      @doc_id = self.doc_root.object_id
      node.instance_variable_set(:@doc_id, self.doc_root.object_id)

      self
    end      

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
              if x[0] != 'class' then
                x[1] = '==' if x[1] == '='
                "h[:'%s'] %s %s" % x
              else
                "h[:class] and h[:class].include? %s" % x.last
              end
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
                  
                  if x[0][/@\w+$/] then
                    "r = e.xpath('#{path}').first; r and r == #{value}"
                  else
                    "r = e.xpath('#{path}').first; r and r.value == #{value}"
                  end
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

      if path == '//' then
        return [node, node.text, 
          node.elements.map {|x| scan_match x, path}]
      end

      r = []
      xpath2 = path[2..-1] 
      xpath2.sub!(/^\*\//,'')
      xpath2.sub!(/^\*/,self.name)
      xpath2.sub!(/^\w+/,'').sub!(/^\//,'') if xpath2[/^\w+/] == self.name
      

      r << node.xpath(xpath2)
      r << node.elements.map {|n| scan_match(n, path) if n.is_a? Rexle::Element}
      r
    end

    # used by xpath function contains()
    #
    def scan_contents(node)

      a = []
      a << node.text

      node.elements.each do |child|
        a.concat scan_contents(child)
      end
      a
    end
    
    
    def filter(raw_element, i, attr_search, &blk)

      x, index = raw_element
      e = @child_elements[index]

      return unless e.is_a? Rexle::Element
      name, value = e.name, e.value if e.is_a? Rexle::Element

      h = x.attributes  # <-- fetch the attributes      
      
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
      elsif h and !h.empty? and attr_search[/^h\[/] and eval(attr_search) then
        block_given? ? blk.call(e) : e
      elsif attr_search[/^\(name ==/] and e.child_elements.select {|x| 
            next unless x.is_a? Rexle::Element
            name, attributes, value = x.name, x.attributes, x.value.to_s
            b = eval(attr_search)
            b}.length > 0

        block_given? ? blk.call(e) : e
        
      elsif attr_search[/^\(name ==/] and eval(attr_search) 
        block_given? ? blk.call(e) : e          
      elsif attr_search[/^e\.value/]

        v = attr_search[/[^\s]+$/]
        duck_type = %w(to_f to_i to_s).detect {|x| v == v.send(x).to_s}
        attr_search.sub!(/^e.value/,'e.value.' + duck_type)

        if eval(attr_search) then
          block_given? ? blk.call(e) : e
        end
      elsif attr_search[/e\.xpath/] and eval(attr_search)           
        block_given? ? blk.call(e) : e
      elsif e.element attr_search then
        block_given? ? blk.call(e) : e
      end      
    end
    
    def recursive_scan(nodes, &blk)
      
      nodes.each do |x|

        if x.is_a? Rexle::Element then
          blk.call(x)
          recursive_scan(x.children, &blk) if x.children.length > 0
        end      
      end
    end
        
  end # -- end of element --
  

  class CData
    
    def initialize(val='')
      @value = val
    end
    
    def clone()
      CData.new(@value)
    end
    
    def inspect()
      @value.inspect
    end
    
    def print()
      "<![CDATA[%s]]>" % @value
    end
    
    def to_s()
      @value
    end
    
    def unescape()
      s = @value.clone
      %w(&lt; < &gt; > &amp; & &pos; ').each_slice(2){|x| s.gsub!(*x)}
      s
    end    
    
  end
  
  class Comment
    
    def initialize(val='')
      @value = val
    end
    
    def inspect()
      @value
    end
    
    def print()
      "<!--%s-->" % @value
    end
    
    def to_s()
      @value
    end
  end
  
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
        Array: proc {|x| x}
      }
      a = procs[x.class.to_s.to_sym].call(x)
    else    
      a = yield
    end
    
    doc_node = ['doc',{}]
    @a = procs[x.class.to_s.to_sym].call(x)
    @doc = scan_element(*(doc_node << @a))
    
    self
  end

  def add_attribute(x) @doc.attribute(x) end
  def attribute(key) @doc.attribute(key) end
  def attributes() @doc.attributes end
    
  def add_element(element)  

    if @doc then     
      raise 'attempted adding second root element to document' if @doc.root
      @doc.root.add_element(element) 
    else
      doc_node = ['doc', {}, element.to_a]  
      @doc = scan_element(*doc_node)      
    end
    element
  end
  
  def add_text(s) end

  alias add add_element

  def delete(xpath)

    e = @doc.element(xpath)
    e.delete if e
  end
  
  alias remove delete

  def element(xpath) self.xpath(xpath).first end  
  def elements(s=nil) @doc.elements(s) end
  def name() @doc.root.name end
  def to_a() @a end
    
  def to_s(options={}) 
    return '<UNDEFINED/>' unless @doc
    self.xml options 
  end
  
  def text(xpath) @doc.text(xpath) end
  def root() @doc.elements.first end

  def write(f) 
    f.write xml 
  end

  def xml(options={})

    return '' unless @doc
    o = {pretty: false, declaration: true}.merge(options)
    msg = o[:pretty] == false ? :doc_print : :doc_pretty_print

    r = ''

    if o[:declaration] == true then

      unless @instructions.assoc 'xml' then
        @instructions.unshift ["xml","version='1.0' encoding='UTF-8'"]
      end
    end

    r << method(msg).call(self.root.children, o[:declaration]).strip
    r
  end

  def content(options={})
    CGI.unescapeHTML(xml(options))
  end

  private

  def parse_string(x)

    # check if the XML string is a dynarex document
    if x[/<summary>/] then

      recordx_type = x[/<recordx_type>(\w+)/m,1]

      if recordx_type then
        procs = {
          'dynarex' => proc {|x| DynarexParser.new(x).to_a},
          #'polyrex' => proc {|x| PolyrexParser.new(x).to_a},
          'polyrex' => proc {|x| RexleParser.new(x).to_a}
        }
        procs[recordx_type].call(x)
        
      else

        rp = RexleParser.new(x)
        a = rp.to_a

        @instructions = rp.instructions
        return a
      end
    else

      rp = RexleParser.new(x)
      a = rp.to_a
      @instructions = rp.instructions
      return a
  
    end

  end
    
  def scan_element(name, attributes=nil, *children)

    return Rexle::CData.new(children.first) if name == '!['

    element = Rexle::Element.new(name, attributes: attributes, rexle: self)  

    if children then

      children.each do |x|
        if x.is_a? Array then

          element.add_element scan_element(*x)        
        elsif x.is_a? String then

          e = if x.is_a? String then

            x
          elsif x.name == '![' then

            Rexle::CData.new(x)
          end

          element.add_element e
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
