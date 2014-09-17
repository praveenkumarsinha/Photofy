Gem::Specification.new do |s|
  s.name = 'photofy'
  s.version = '0.2.2'
  s.date = '2014-08-05'
  s.summary = "Photofy"
  s.description = <<-EOF
    A gem to provide simple method to do file upload of pictures and provides getter setter methods of it and save on model object commit.

      #Generates photo filed from photo_field arguments and provides methods like
      #if photo_filed is \"collage\" then it provides methods on top of it as
      #collage >> Getter,
      #collage? >> Returns true if assignment is having value other than nil else false,
      #collage =  >> Setter. Acceptable inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(format validation is ignored),
      #collage_path >> File path of assignment,
      collage_s3publicpath >> Public aws s3 url provider if (aws s3 is used as storage),
      #collage_path_to_write >> File path of assignment to write (specific to writing. Used internally),
      #collage_persisted? >> true if provided file/data is stored on disk,
      #collage_store! >> to store provided  file/data on disk,
      #collage_destroy! >> to store destroy stored file/data from disk
  EOF
  s.authors = ["Praveen Kumar Sinha", "Annu Yadav", "Sachin Choudhary"]
  s.email = 'praveen.kumar.sinha@gmail.com'
  s.files = ["lib/photofy.rb", "lib/photofy/core.rb", "lib/photofy/s3methods.rb"]
  s.licenses = ['MIT', 'GPL-2']
  s.add_runtime_dependency 'aws-sdk', '~> 1.49', '>= 1.49.0'
  s.homepage = 'http://praveenkumarsinha.github.io/Photofy'
  s.post_install_message = "Thanks for installing Photofy."
end



