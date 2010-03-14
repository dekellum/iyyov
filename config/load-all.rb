
Iyyov.context do |c|

  # Load all the other config examples in this directory.  Avoid
  # recursively reading self.
  Dir[ File.join( File.dirname( __FILE__ ), '*.rb' ) ].each do |conf|
    c.load_file( conf ) unless conf == __FILE__
  end

end
