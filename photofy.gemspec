Gem::Specification.new do |s|
  s.name        = 'photofy'
  s.version     = '0.1.2'
  s.date        = '2012-03-15'
  s.summary     = "Photofy"
  s.description = "A gem to provide simple method to do file upload of pictures and provides getter setter methods of it and save on model object commit.
    #Generates photo filed from photo_field arguments and provides methods like
    #if photo_filed is \"collage\" then it provides methods on top of it as
    #collage >> Getter,
    #collage =  >> Setter. Accepted inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(no format validation is ignored),
    #collage_path >> Getter of filepath,
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk"
  s.authors     = ["Praveen Kumar Sinha"]
  s.email       = 'praveen.kumar.sinha@gmail.com'
  s.files       = ["lib/photofy.rb"]
  s.homepage    = 'https://github.com/praveenkumarsinha/Photofy'
end



