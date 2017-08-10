#!/usr/bin/env ruby

# file: rexle.rb

require 'rexleparser'
#jr240716 require 'dynarex-parser'
#jr240716 require 'polyrex-parser'
require 'rexle-css'
require 'cgi'
require 'backtrack-xpath'


# modifications:
# 10-Aug-2017: feature: Rexle now has a member variable (@rexle) to keep 
#              track of the working document when elements are passed to 
#                                different documents
# 13-Apr-2017: bug fix: Rexle::Elements#index was implemented which fixes the 
#         Rexle::Element#next_sibling and Rexle::Element#previous_sibling  bugs
# 25-Feb-2017: improvement: 
#                       An input rexle array can now have an empty array for 
#                       children e.g. doc = Rexle.new(["records", {}, "", []])
# 25-Dec-2016: revision for Ruby 2.4: Replaced Fixnum with Integer
# 11-Dec-2016: backtrack improvement: The usage of attributes (ID, or class) in the returned XPath is now optional
# 11-Nov-2016: bug fix: escaped string using double quotes instead regarding 
#                       attr_search
# 24-Aug-2016: bug fix: Replaced the Dynarex parser with the native parser
# 08-Jul-2016: bug fix: Dynarex#css will no longer return the Rexle 
#                       object in the results e.g. doc.css '*'
# 21-May-2016: bug fix: If an xpath containing and attribute only is passed 
#                       into method Rexle::Element#text it will now call the 
#                       attribute's value
#              design fix: When an attribute is specified within an XPath, a 
#                          Rexle::Element::Attribute object is now returned
# 15-May-2016: bug fix: Rexle::Element::add_attribute can now handle the 
#                       object Attribute::Value
# 06-May-2016: feature: Rexle::Element.text now returns a 
#                       Rexle::Element::Value object which is a kind of 
#                       String which be used for comparing numbers
# 25-Apr-2016: bug fix: Rexle::Element#to_a no longer returns a 
#                       duplicate text value
# 24-Apr-2016: bug fix: The element text is now enclosed within quotes when 
#              evaluating an xpath condition. see xpath improvement 23-apr-2016
# 23-Apr-2016: xpath improvement: Better predicate support 
#                                 e.g. e.xpath("node != ''")
#              revision: The previous feature can now include simple 
#                        predicate logic e.g. 2 < 5
# 22-Apr-2016: feature: Using an XPath A pure logic predicate can now be 
#                       processed e.g. (4 % 1) != 1
# 21-Apr-2016: feature: The xpath() method now returns a Rexle::Recordset object 
#                       which itself can be treat as a Rexle document
#              An xpath predicate can now contain the mod operator as well as 
#              containing nested logic  e.g. [(position() mod 2) == 1]
# 16-Apr-2016: improvement: The HTML element div is no longer printed as 
#                           a self-closing tag if empty
# 04-Apr-2016: bug fix: modified the bug fix from the 15-Mar-2016 to 
#              validate on a function name only within the variable attr_search
#              minor improvement: Added a new line character between 
#                                 XML processing instructions
# 28-Mar-2016: minor feature:  the name of an attribute can now be 
#                              passed into Rexle::Element#text
# 15-Mar-2016: bug fix: Reapplied a select case statement (which had 
#                     subsequently been deleted) from method attribute_search()
# 13-Mar-2016: bug fix: Reapplied a statement that was commented out in 
#                       the previous gem release
#              bug fix: Removed a redundant statement from 
#                       method attribute_search()
# 12-Mar-2016: A predicate can now handle position() with the 
#                              equality operator e.g. b[position() = 2]
# 09-Mar-2016: bug fix: '.' now returns the current element
# 02-Mar-2016: improvement: When handling the HTML element iframe, it 
#                                    is no longer printed as a self-closing tag


module XMLhelper

  def doc_print(children, declaration=true)

    body = (children.nil? or children.empty? \
           or children.is_an_empty_string? ) ? '' : \
                          scan_print(children).join.force_encoding("utf-8")

    a = self.root.attributes.to_a.map do |k,v|
      "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v.to_s)]
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
      processing_instructions("") + xml
    else 
      xml
    end
  end
  
  def inspect()    
    "#<Rexle:%s>" % [self.object_id]
  end

  def processing_instructions(s='')
    self.instructions.map do |instruction|
      "<?%s?>\n" % instruction.join(' ') 
    end.join s
  end

  def scan_print(nodes)

    r2 = nodes.map do |x|
      
      r = if x.is_a? Rexle::Element then

        a = x.attributes.to_a.map do |k,v| 
          "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
        end

        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))
        
        non_self_closing_tags = %w(script textarea iframe div object)

        if  (x.children and x.children.length > 0 \
            and not x.children.is_an_empty_string?) or \
              non_self_closing_tags.include? x.name then

          out = ["<%s>" % tag]
          out << scan_print(x.children)

          out << "</%s>" % x.name
        else
          out = ["<%s/>" % tag]
        end
      
      elsif x.is_a? String then  x
      elsif x.is_a? Rexle::CData then x.print        
      elsif x.is_a? Rexle::Comment then x.print        
        
      end

      r
    end
    
    r2

  end
  
  def scan_to_a(nodes)

    nodes.inject([]) do |r,x|

      if x.is_a? Rexle::Element then

        a = [String.new(x.name), Hash.new(x.attributes), x.value.to_s]

        (a.concat(scan_to_a(x.children))) if x.children.length > 1
        r << a
      elsif x.is_a? String then

        r << String.new(x)
      end

    end

  end
  


  def pretty_print(nodes, indent='0')

    indent = indent.to_i
    return '' unless nodes

    nodes.select(){|x| x.to_s.strip.length > 0}
        .map.with_index do |x, i|

      if x.is_a? Rexle::Element then

        a = x.attributes.to_a.map do |k,v| 
          "%s='%s'" % [k,(v.is_a?(Array) ? v.join(' ') : v)]
        end
        a ||= []

        tag = x.name + (a.empty? ? '' : ' ' + a.join(' '))
        start = i > 0 ? ("\n" + '  ' * (indent - 1)) : ''          

        if (x.value and x.value.length > 0) \
            or (x.children and x.children.length > 0 \
            and not x.children.is_an_empty_string?) or \
              x.name == 'script' or x.name == 'textarea' or \
                                                  x.name == 'iframe' then

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
  
  def initialize(x=nil, rexle: self)

    @rexle = rexle
    super()

    @instructions = [["xml", "version='1.0' encoding='UTF-8'"]] 
    @doctype = :xml

    # what type of input is it? Is it a string, array
    if x then
      procs = {
        String: proc {|x| parse_string(x)},
        Array: proc {|x| x},
        RexleParser: ->(x){ parse_rexle(x)}
      }
      
      doc_node = ['doc',Attributes.new]
  
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
    
    a = selector.split(',').flat_map do |x| 
      @doc.root.xpath RexleCSS.new(x).to_xpath
    end
    
    a.shift if self.kind_of? Rexle
    
    return a
  end
  
  def xpath(path,  &blk)
    @doc.xpath(path,  &blk)
  end  

  class Element
    include XMLhelper
    
    class Value < String
      
      def initialize(value)
        super(value)
      end
            
      def <(val2)
        self.to_f < val2.to_f
      end      
      
      def >(val2)
        self.to_f > val2.to_f
      end            
    end   
    
    class Attribute
      
      attr_reader :value
      
      def initialize(value)
        @value = value
      end
      
      def to_f()
        @value.to_f
      end      
      
      def to_i()
        @value.to_i
      end
      
      alias to_s value
        
    end
    
    attr_accessor :name, :value, :parent
    attr_reader :child_elements, :doc_id, :instructions
    
    alias original_clone clone

    def initialize(name=nil, value: nil, attributes: Attributes.new, rexle: self)

      @rexle = rexle      
      super()

      @name, @attributes = name.to_s, attributes

      raise "Element name must not be blank" unless name
      @child_elements = []
      self.add_text value if value

    end
    
    def backtrack(use_attributes: true)
      BacktrackXPath.new(self, use_attributes: use_attributes)
    end
    
    def cdata?()
      self.is_a? CData
    end

    def contains(raw_args)

      path, raw_val = raw_args.split(',',2)
      val = raw_val.strip[/^["']?.*["']?$/]      
      
      anode = query_xpath(path)

      return [false] if anode.nil? or anode.empty?

      a = scan_contents(anode.first)
      r = [a.grep(/#{val.sub(/^["'](.*)["']$/,'\1')}/).length > 0]

      r.any?
    end    
    
    def count(path)
      length = query_xpath(path).flatten.compact.length
      length
    end
    
    def current()
      self
    end

    def at_css(selector)
      self.root.element RexleCSS.new(selector).to_xpath
    end 
    
    def css(selector)

      selector.split(',')\
                  .flat_map{|x| self.root.xpath RexleCSS.new(x).to_xpath}
    end    
    
    def max(path) 
      a = query_xpath(path).flatten.select{|x| x.is_a? String or x.is_a? Rexle::Element::Attribute}.map(&:to_i)
      a.max 
    end
      
    def name()
      
      if @rexle then
        
        if @rexle.prefixes.is_a? Array then
          prefix = @rexle.prefixes.find {|x| x == @name[/^(\w+):/,1] } 
        end
        
        prefix ? @name.sub(prefix + ':', '') : @name
        
      else
        @name
      end
      
    end
    
    def next_element()      

      id  = self.object_id
      a = self.parent.elements      

      i = a.index {|x| x.object_id == id} + 2
      a[i] if  i < a.length + 1
        
    end
    
    alias next_sibling next_element
    
    def not(bool)

      r = self.xpath(bool).any?

      !r
    end
    
    def previous_element()      
      
      id  = self.object_id
      a = self.parent.elements      
      i = a.index {|x| x.object_id == id}

      a[i] if  i > 0 

    end
    
    alias previous_sibling previous_element
    
    def xpath(path, rlist=[], &blk)
      
      #@log.debug 'inside xpath ' + path.inspect

      r = filter_xpath(path, rlist=[], &blk)
      #@log.debug 'after filter_xpath : ' + r.inspect
      
      if r.is_a?(Array) then
        
        Recordset.new(r.compact)
        
      else
        r
      end
      
    end
    
    def filter_xpath(raw_path, rlist=[], &blk)
      #@log.debug 'inside filter_xpath : ' + raw_path.inspect
      path = String.new raw_path

      # is it a function
      fn_match = path.match(/^(\w+)\(["']?([^\)]*)["']?\)(?:\[(.*)\])?$/)
      #fn_match = path.match(/^(\w+)\(/)
      #@log.debug 'fn_match : ' + fn_match.inspect
      end_fn_match = path.slice!(/\[\w+\(\)\]$/)
      
      if end_fn_match then
        
        m = end_fn_match[1..-4]
        #@log.debug 'its a function'
        [method(m.to_sym).call(xpath path)]
      
      elsif (fn_match and fn_match.captures.first[/^(attribute|@)/]) 

        procs = {

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
        
      elsif fn_match.nil?
        
        procs = {

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

        return [true] if !path[/[><]/] and raw_results.flatten.index(true)
        results = raw_results # .flatten.select {|x| x}
        
        procs[results.class.to_s.to_sym].call(results) if results            

      else
        
        m, xpath_value, index = fn_match.captures        

        if m == 'text' then
          a = texts()
          return index ? a[index.to_i - 1].to_s : a
        end
        #@log.debug 'before function call'
        raw_results = xpath_value.empty? ? method(m.to_sym).call \
                                    : method(m.to_sym).call(xpath_value)

        raw_results

      end

    end    
    
    def query_xpath(raw_xpath_value, rlist=[], &blk)

      #@log.debug 'query_xpath : ' + raw_xpath_value.inspect
      #@log.debug '++ ' + self.xml.inspect

      flag_func = false            

      xpath_value = raw_xpath_value.sub('child::','./')

      if xpath_value[/^[\w\/]+\s*=.*/] then

        flag_func = true

        xpath_value.sub!(/^\w+\s*=.*/,'.[\0]')
        xpath_value.sub!(/\/([\w]+\s*=.*)/,'[\1]')

      end

      raw_path, raw_condition = xpath_value.sub(/^\.?\/(?!\/)/,'')\
          .match(/([^\[]+)(\[[^\]]+\])?/).captures

      remaining_path = ($').to_s

      #@log.debug 'remaining_path: ' + remaining_path.inspect

      if remaining_path[/^contains\(/] then

        raw_condition = raw_condition ? raw_condition + '/' + remaining_path \
                                                               : remaining_path
        remaining_path = ''        
      end

      r = raw_path[/^([^\/]+)(?=\/\/)/,1] 

      if r then
        a_path = raw_path.split(/(?=\/\/)/,2)
      else
        a_path = raw_path.split('/',2)
      end
      
      condition = raw_condition if a_path.length <= 1 #and not raw_condition[/^\[\w+\(.*\)\]$/]

      if raw_path[0,2] == '//' then
        s = ''
      elsif raw_path == 'text()'        

        a_path.shift
        #return @value
        return self.texts
      else

        attribute = xpath_value[/^(attribute::|@)(.*)/,2] 
  
        return @attributes  if attribute == '*'
        
        if attribute and @attributes and \
              @attributes.has_key?(attribute.to_sym) then
          return [Attribute.new(@attributes[attribute.to_sym])]
        end
        s = a_path.shift
      end      

      # isolate the xpath to return just the path to the current element

      elmnt_path = s[/^([a-zA-Z:\-\*]+\[[^\]]+\])|[\/]+{,2}[^\/]+/]
      element_part = elmnt_path[/(^@?[^\[]+)?/,1] if elmnt_path

      if element_part then

        unless element_part[/^(@|[@\.a-zA-Z]+[\s=])/] then

          element_name = element_part[/^[\w:\-\*\.]+/]

          if element_name and element_name[/^\d/] then
            element_name = nil
          end
          
          condition = raw_xpath_value if element_name.nil?

        else

          if xpath_value[/^\[/] then
            condition = xpath_value
            element_name = nil
          else
            condition = element_part
            attr_search = format_condition('[' + condition + ']')

            #@log.debug 'attr_search : ' + attr_search.inspect
            return [attribute_search(attr_search, \
                                     self, self.attributes) != nil]
          end

        end

      end

      #element_name ||= '*'
      raw_condition = '' if condition

      attr_search = format_condition(condition) if condition \
                                                and condition.length > 0

      #@log.debug 'attr_search2 : ' + attr_search.inspect
      attr_search2 = xpath_value[/^\[(.*)\]$/,1]

      if attr_search2 then
        #@log.debug 'before attribute_Search'
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

        if ename == '..' then
          
          remaining_xpath = raw_path[/\.\.\/(.*)/,1]
          # select the parent element

          r2 =  self.parent.xpath(remaining_xpath)

          return r2
          
        elsif ename == '.'

          remaining_xpath = raw_path[1..-1]

          return remaining_xpath.empty? ? self : self.xpath(remaining_xpath)
        elsif element_name.nil?
          return eval attr_search          
        else

          if raw_selector.nil? and ename != element_part  then

            right_cond = element_part[/#{ename}(.*)/,1]

          end                    

          return_elements = @child_elements.map.with_index.select do |x, i|

            next unless x.is_a? Rexle::Element

            #x.name == ename or  (ename == '*')
            
            r10 = ((x.name == ename) or  (ename == '*'))

            

          end
          
          if right_cond then
                        
            
            r12 = return_elements.map do |x, i|

              if x.text then

                r11 = eval "'%s'%s" % [x.text.to_s, right_cond]

              else
                false
              end
              
            end
            
            return r12
            
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
                    

        end
      end
                
      if return_elements.length > 0 then

        if (a_path + [remaining_path]).join.empty? then

          # pass in a block to the filter if it is function contains?
          rlist = return_elements.map.with_index do |x,i| 
            r5 = filter(x, i+1, attr_search, &blk)

            r5
          end.compact

          rlist = rlist[0] if rlist.length == 1

        else

          rlist << return_elements.map.with_index do |x,i| 

            rtn_element = filter(x, i+1, attr_search) do |e| 

              r = e.xpath(a_path.join('/') + raw_condition.to_s \
                    + remaining_path, &blk)

              r = e if r.is_a?(Array) and r.first and r.first == true \
                                                              and a_path.empty?

              r
            end

            next if rtn_element.nil? or (rtn_element.is_a? Array \
                                                      and rtn_element.empty?)

            if rtn_element.is_a? Hash then
              rtn_element
            elsif rtn_element.is_a? Array then
              rtn_element
            elsif (rtn_element.is_a? String) || (rtn_element.is_a?(Array) \
                                          and not(rtn_element[0].is_a? String))
              rtn_element
            elsif rtn_element.is_a? Rexle::Element
              rtn_element
            elsif rtn_element  == true
              true
            end
          end

          rlist = rlist.flatten(1) unless rlist.length > 1 \
                                                       and rlist[0].is_a? Array
          rlist

        end

        rlist.compact! if rlist.is_a? Array

      else

        # strip off the 1st element from the XPath
        new_xpath = xpath_value[/^\/\/[\w:\-]+\/(.*)/,1]

        if new_xpath then
          self.xpath(new_xpath + raw_condition.to_s + remaining_path, \
                                                                rlist,&blk)
        end
      end
 
      rlist = rlist.flatten(1) unless not(rlist.is_a? Array) \
                                 or (rlist.length > 1 and rlist[0].is_a? Array)
      rlist = [rlist] if rlist.is_a? Rexle::Element
      rlist = (rlist.length > 0 ? true : false) if flag_func == true

      rlist
    end

    def add_element(item)

      if item.is_a? String then
        @child_elements << Value.new(item)

      elsif item.is_a? Rexle::CData then
        @child_elements << item
      elsif item.is_a? Rexle::Comment then
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

    def add_attribute(*x)
      
      proc_hash = lambda {|x| Hash[*x]}
      
      procs = {
        Hash: lambda {|x| x[0] || {}},
        String: proc_hash,
        Symbol: proc_hash,
        :'Attributes::Value' => proc_hash
      }

      type = x[0].class.to_s.to_sym

      h = procs[type].call(x)

      @attributes.merge! h
    end

    def add_text(s)

      self.child_elements << s
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

      r =  @child_elements
      
      def r.is_an_empty_string?()
        self.length == 1 and self.first == ''
      end      
      
      return r
    end 

    def children=(a)   @child_elements = a if a.is_a? Array  end
    
    def deep_clone() Rexle.new(self.xml).root end
      
    def clone() 
      Element.new(@name, attributes: @attributes) 
    end
          
    def delete(obj=nil)

      if obj then

        if obj.is_a? String then
          
          self.xpath(obj).each {|e| e.delete}
          
        else

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
        NilClass: proc {Elements.new(@child_elements\
                                     .select{|x| x.kind_of? Rexle::Element })},
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
      
      return self.value if s.empty? 
      
      e = self.element(s)
      return e if e.is_a? String
      
      e.value if e
    end
    
    def texts()

     r = @child_elements.select do |x|
        x.is_a? String or x.is_a? Rexle::CData
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
      return nil unless r.is_a? String
      
      def r.unescape()
        s = self.clone
        %w(&lt; < &gt; > &amp; & &pos; ').each_slice(2){|x| s.gsub!(*x)}
        s
      end     
      
      return r
    end
        
    def value=(raw_s)

      val = Value.new(raw_s.to_s.clone)
      
      escape_chars = %w(& &amp; < &lt; > &gt;).each_slice(2).to_a
      escape_chars.each{|x| val.gsub!(*x)}

      t = val

      @child_elements.any? ? @child_elements[0] = t : @child_elements << t
    end

    alias text= value=
        
    def to_a()
      e = [String.new(self.name), Hash.new(self.attributes)]
      [*e, *scan_to_a(self.children)]
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

    def prepend(item)
      
      @child_elements.unshift item
      
      # add a reference from this element (the parent) to the child
      item.parent = self
      item              
    end    
    
    alias to_s xml

    private
    
    def insert(node,offset=0)

      i = parent.child_elements.index(self)
      return unless i

      parent.child_elements.insert(i+offset, node)

      @doc_id = self.doc_root.object_id
      node.instance_variable_set(:@doc_id, self.doc_root.object_id)

      self
    end      

    def format_condition(condition)

      raw_items = condition.sub(/\[(.*)\]/,'\1').scan(/\'[^\']*\'|\"[^\"]*\"|\
         and|or|\d+|[!=<>%]+|position\(\)|contains\([^\)]+\)|not\([^\)]+\)|[@\w\.\/&;]+/)

      if raw_items[0][/^\d+$/] then

        if condition[0 ] == '[' then
          return raw_items[0].to_i
        else
          return condition
        end
      elsif raw_items[0] == 'position()' then

        rrr = condition[1..-2].gsub(/position\(\)/,'i').gsub('&lt;','<')\
            .gsub('&gt;','>').gsub(/\s=\B/,' ==').gsub(/\bmod\b/,'%')

        return rrr
      elsif raw_items[0][/^contains\(/]
        return raw_items[0]
      elsif  raw_items[0][/^not\(/]

        return raw_items[0]
      else

        andor_items = raw_items.map.with_index\
            .select{|x,i| x[/\band\b|\bor\b/]}\
            .map{|x| [x.last, x.last + 1]}.flatten
        
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
                    "r = e.xpath('#{path}').first; r and r.value == #{value}"
                  else
                    "r = e.xpath('#{path}').first; r and r.value == #{value}"
                  end
                else
                  "(name == '%s' and value %s \"%s\")" % [x[0], x[1], \
                                             x[2].sub(/^['"](.*)['"]$/,'\1')]
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
      #jr150316 xpath2.sub!(/^\*\//,'')
      #jr150316xpath2.sub!(/^\*/,self.name)
      #jr150316xpath2.sub!(/^\w+/,'').sub!(/^\//,'') if xpath2[/^\w+/] == self.name

      r << node.xpath(xpath2)
      r << node.elements.map {|n| scan_match(n, path) if n\
                                                    .is_a? Rexle::Element}
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

        r6 = attribute_search(attr_search,e, h, i, &blk)
        r6
      else

        block_given? ? blk.call(e) : e
      end

    end

    def attribute_search(attr_search, e, h, i=nil, &blk)

      r2 = if attr_search.is_a? Integer then
        block_given? ? blk.call(e) : e if i == attr_search 
      elsif attr_search[/i\s(?:<|>|==|%)\s\d+/] and eval(attr_search) then
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
      elsif attr_search[/^\w*\(/] and e.element(attr_search)
        block_given? ? blk.call(e) : e
      end      

      r2
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

    def [](raw_i)

      raise 'Rexle::Elements index (-1) must be >= 1' unless raw_i > 0
      i = raw_i - 1
      @elements[i]
    end
    
    def each(&blk) @elements.each(&blk)  end
    def empty?()   @elements.empty?      end
    
    def index(e=nil, &blk)
      
      if block_given? then
        @elements.index(&blk)
      else
        @elements.index e
      end
    end
    
    def length()   @elements.length      end
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
    
    doc_node = ['doc',Attributes.new]
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
      doc_node = ['doc', Attributes.new, element.to_a]  
      @doc = scan_element(*doc_node)      
    end
    element
  end
  
  def add_text(s) end

  alias add add_element

  def delete(xpath)

    @doc.xpath(xpath).each {|e| e.delete }

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
  def root() 
    @doc.elements.first 
  end

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

  def parse_rexle(x)
    
    rp = RexleParser.new(x)
    a = rp.to_a

    @instructions = rp.instructions
    return a              
  end
  
  def parse_string(x)

    # check if the XML string is a dynarex document
    if x[/<summary>/] then

      recordx_type = x[/<recordx_type>(\w+)/m,1]

      if recordx_type then
        procs = {
          #'dynarex' => proc {|x| DynarexParser.new(x).to_a},
          'dynarex' => proc {|x| parse_rexle(x)},
          #'polyrex' => proc {|x| PolyrexParser.new(x).to_a},
          'polyrex' => proc {|x| parse_rexle(x)}
        }
        other_parser = procs[recordx_type]
        
        if other_parser then
          
          begin
            other_parser.call(x)
          rescue
            parse_rexle x
          end
          
        else
          
          parse_rexle x
  
        end        
        
      else

        parse_rexle x
        
      end
    else

      parse_rexle x
  
    end

  end
    
  def scan_element(name=nil, attributes=nil, *children)
    
    return unless name
    
    return Rexle::CData.new(children.first) if name == '!['
    return Rexle::Comment.new(children.first) if name == '!-'

    element = Rexle::Element.new(name, attributes: attributes, rexle: @rexle)  

    if children then

      children.each do |x4|
        

        if x4.is_a? Array then
          element.add_element scan_element(*x4)        
        elsif x4.is_a? String then

          e = if x4.is_a? String then

            x4
          elsif x4.name == '![' then

            Rexle::CData.new(x4)
            
          elsif x4.name == '!-' then

            Rexle::Comment.new(x4)
            
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
  
  class Recordset < Array

    def initialize(a)
      super(a)
    end
    
    def to_doc(root: 'root')
      
      recordset = self.map(&:to_a)
      Rexle.new([root,{}, *recordset])
    
    end
    
    def xpath(xpath)
      self.to_doc.root.xpath(xpath)
    end
    
    def element(xpath)
      self.to_doc.root.element(xpath)
    end

  end  
    
end