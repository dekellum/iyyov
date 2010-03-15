Iyyov.context do |c|

  hostname = `hostname -s`.strip
  SLF4J[ File.basename( __FILE__ ) ].info( "Setup services for [#{hostname}]." )

  case hostname

  when /^server-[012]$/
    c.define_daemon { |d| d.name = "widget-factory" }

  when 'server-3'
    c.define_daemon { |d| d.name = "assembly-line" }

  end
end
