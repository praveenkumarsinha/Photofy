Gem::Specification.new do |s|
  s.name = 'photofy'
  s.version = '0.5.2'
  s.date = '2015-03-26'
  s.summary = "Photofy"
  s.description = <<-EOF
    A simple gem to add accessors on rails models for file upload of pictures/assets (which will be persisted on remote media's disk on object save).
    Refer documentation for more help.
  EOF
  s.authors = ["Praveen Kumar Sinha", "Annu Yadav", "Sachin Choudhary"]
  s.email = 'praveen.kumar.sinha@gmail.com'
  s.files = Dir["{lib}/**/*", "README.md"]
  s.licenses = ['MIT', 'GPL-2']
  s.homepage = 'http://praveenkumarsinha.github.io/Photofy'
  s.post_install_message = "Thanks for installing Photofy."
end



