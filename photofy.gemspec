Gem::Specification.new do |s|
  s.name = 'photofy'
  s.version = '0.3.5'
  s.date = '2014-11-16'
  s.summary = "Photofy"
  s.description = <<-EOF
    A gem to provide simple method to do file upload of pictures and provides getter setter methods of it and save on model object commit.
    Refer documentation for more help.
  EOF
  s.authors = ["Praveen Kumar Sinha", "Annu Yadav", "Sachin Choudhary"]
  s.email = 'praveen.kumar.sinha@gmail.com'
  s.files = Dir["{lib}/**/*", "README.md"]
  s.licenses = ['MIT', 'GPL-2']
  s.add_runtime_dependency 'aws-sdk', '~> 1.49', '>= 1.49.0'
  s.homepage = 'http://praveenkumarsinha.github.io/Photofy'
  s.post_install_message = "Thanks for installing Photofy."
end



