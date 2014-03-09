Gem::Specification.new do |s|
  s.name        = 'photofy'
  s.version     = '0.1.7'
  s.date        = '2014-03-06'
  s.summary     = "Photofy"
  s.description = "A gem to provide simple method to do file upload of pictures and provides getter setter methods of it and save on model object commit.
    #Generates photo filed from photo_field arguments and provides methods like
    #if photo_filed is \"collage\" then it provides methods on top of it as
    #collage >> Getter,
    #collage? >> Returns true if assignment is having value other than nil else false,
    #collage =  >> Setter. Acceptable inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(format validation is ignored),
    #collage_path >> File path of assignment,
    #collage_path_to_write >> File path of assignment to write (specific to writing. Used internally),
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk"
  s.authors     = ["Praveen Kumar Sinha", "Annu Yadav", "Sachin Choudhary"]
  s.email       = 'praveen.kumar.sinha@gmail.com'
  s.files       = ["lib/photofy.rb"]
  s.homepage    = 'http://praveenkumarsinha.github.io/Photofy'
end



