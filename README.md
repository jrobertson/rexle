# Introducing the Rexle gem

    require 'rexle'

    s = "&lt;a&gt;ddd&lt;trust colour='red'&gt;abc&lt;/trust&gt;&lt;ccc&gt;rrr&lt;/ccc&gt;&lt;/a&gt;"
    doc = Rexle.new s
    r = doc.root.xpath 'trust'
    r.first.value
    #=&gt; abc

    r.first.attributes
    #=&gt; {"colour"=&gt;"red"}

    s = "&lt;a&gt;ddd&lt;trust&gt;abc&lt;/trust&gt;&lt;ccc&gt;rrr&lt;/ccc&gt;&lt;/a&gt;"
    Rexle.new(s).root.element('trust').value
    #=&gt; abc

    s = "&lt;a&gt;ddd&lt;trust&gt;abc&lt;/trust&gt;&lt;ccc&gt;&lt;eee&gt;fff&lt;/eee&gt;&lt;/ccc&gt;&lt;/a&gt;"
    Rexle.new(s).root.element('ccc/eee').value
    #=&gt; "fff"
    
Rexle is an XML parser intended for returning elements from an XPath query faster than REXML, and Nokogiri.

## Resources

* [jrobertson's rexle](http://github.com/jrobertson/rexle)

