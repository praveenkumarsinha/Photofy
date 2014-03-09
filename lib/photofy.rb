begin
  require "RMagick"
rescue Exception => e
  puts "Unable to load 'RMagick' for any image manipulations methods"
end

module Photofy
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    attr_accessor :photofied_flag
    attr_accessor :photo_fields
    attr_accessor :photos_repository
    attr_accessor :photo_formats

    #Getter to check if model is enabled with file_folder
    def is_photofied?
      @photofied_flag.nil? ? false : @photofied_flag
    end

    #Generates photo field which can be used to store a post processed image(using rmagick) of parent photo field.
    #Takes three arguments:
    #1. parent photo field name
    #2. field name
    #3. Proc with rmagick img object
    #return value should be an object of rmagick's image object
    #
    #Example usage..
    #after_photofy :profile, :stamp, Proc.new{|img| img.scale(25, 25)}
    #will give a 'stamp' attribute which on save of 'profile' photo field will scale it to 25 x 25 dimensions
    #after_photofy :profile, :portfolio, Proc.new{|img| img.scale(150, 250)}
    #will give a 'portfolio' attribute which on save of 'profile' photo field will scale it to 150 x 250 dimensions
    def after_photofy(parent_photo_field, photo_field, proc = Proc.new { |img| puts "Rmagick image: #{img.inspect}" })
      photofy(photo_field, image_processor: proc, parent_photo_field: parent_photo_field)
    end

    #Example
    #photofy(:door)
    #photofy(:small_door, {parent_photo_field: :door})
    #photofy(:window, {image_processor: Proc.new { |img| img.scale(25, 25) }})
    #after_photofy :door, :ventilator, Proc.new { |img| img.scale(25, 25) }
    #
    #Generates photo filed from photo_field arguments and provides methods like
    #if photo_filed is "collage" then it provides methods on top of it as
    #collage >> Getter,
    #collage? >> Returns true if assignment is having value other than nil else false,
    #collage =  >> Setter. Acceptable inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(format validation is ignored),
    #collage_path >> File path of assignment,
    #collage_path_to_write >> File path of assignment to write (specific to writing. Used internally),
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk
    #
    #Options:
    #image_processor: a proc for image processing like Proc.new { |img| img.scale(25, 25) }
    #parent_photo_field: a parent photo field name to be used as source
    def photofy(photo_field, options = {})
      collect_photo_formats(photo_field, options)

      @photo_fields ||=[]
      @photo_fields << photo_field

      define_method 'initialize_photo_buffers' do
        @photo_file_buffer ||= {}
        @photo_file_ofn ||= {}
      end

      #Defining getter
      define_method "#{photo_field}" do
        send('initialize_photo_buffers')

        if @photo_file_buffer[photo_field].nil?
          send("#{photo_field}_persisted?") ? File.read(send("#{photo_field}_path")) : nil
        else
          @photo_file_buffer[photo_field]
        end
      end

      define_method "#{photo_field}?" do
        send("#{photo_field}").nil? ? false : true
      end

      #Defining setter
      define_method "#{photo_field}=" do |file_upload|
        send('initialize_photo_buffers')

        if file_upload.class == ActionDispatch::Http::UploadedFile
          return false unless self.class.photo_formats[photo_field].include?(File.extname(file_upload.original_filename).downcase)
          @photo_file_buffer[photo_field] = File.read(file_upload.path)
          @photo_file_ofn[photo_field] = File.basename(file_upload.original_filename)

        elsif file_upload.class == File
          return false unless self.class.photo_formats[photo_field].include?(File.extname(file_upload.path).downcase)
          @photo_file_buffer[photo_field] = file_upload.read
          @photo_file_ofn[photo_field] = File.basename(file_upload.path)

          file_upload.rewind
        elsif file_upload.class == String
          #return false unless self.class.photo_formats[photo_field].include?(File.extname(file_upload).downcase)
          @photo_file_buffer[photo_field] = file_upload
          #@photo_file_ofn[photo_field] = File.basename(file_upload.path) #As there is nothing like original_file_name for a string :)
        end

        file_upload
      end

      define_method "#{photo_field}_path" do
        directory_path = FileUtils.mkdir_p File.join(self.class.photos_repository, photo_field.to_s)
        (guessed_file = Dir[File.join(directory_path, "#{self.send(self.class.primary_key).to_s}_*")].first).nil? ?
            File.join(directory_path, self.send(self.class.primary_key).to_s) : guessed_file
      end

      define_method "#{photo_field}_path_to_write" do |overload_dir = nil|
        directoy_path = FileUtils.mkdir_p File.join(self.class.photos_repository, photo_field.to_s, overload_dir.to_s)
        File.join(directoy_path, "#{self.send(self.class.primary_key).to_s}#{(@photo_file_ofn[photo_field].nil?) ? "_" : "_#{@photo_file_ofn[photo_field]}" }")
      end

      define_method "#{photo_field}_persisted?" do
        send('initialize_photo_buffers')
        (@photo_file_buffer[photo_field].nil? and File.file?(send("#{photo_field}_path")))
      end

      define_method "#{photo_field}_store" do |proc, parent_photo_field|
        return unless self.class.is_photofied?

        send('initialize_photo_buffers')

        #Loading content from parent_photo_field if specified
        unless parent_photo_field.nil?
          send("#{photo_field}=", File.open(send("#{parent_photo_field}_path"))) if File.exist?(send("#{parent_photo_field}_path"))
        end

        unless @photo_file_buffer[photo_field].nil?
          File.delete(send("#{photo_field}_path")) if File.exist?(send("#{photo_field}_path")) #Clearing any existing existence
          File.open(send("#{photo_field}_path_to_write"), "wb+") { |f| f.puts(@photo_file_buffer[photo_field]) }

          unless proc.nil?
            FileUtils.copy(send("#{photo_field}_path_to_write"), send("#{photo_field}_path_to_write", "original_source"))
            img = Magick::Image.read(send("#{photo_field}_path")).first
            img = proc.call(img)
            img.write(send("#{photo_field}_path_to_write"))
          end

          @photo_file_buffer[photo_field] = nil
          @photo_file_ofn[photo_field] = nil
        end
      end

      define_method "#{photo_field}_store!" do
        send("#{photo_field}_store", options[:image_processor], options[:parent_photo_field])
      end

      define_method "#{photo_field}_destroy!" do
        return unless self.class.is_photofied?

        send('initialize_photo_buffers')
        @photo_file_buffer[photo_field] = nil
        File.delete(send("#{photo_field}_path")) if File.exist?(send("#{photo_field}_path"))
      end

      send(:after_save, "#{photo_field}_store!")
      send(:after_destroy, "#{photo_field}_destroy!")

      @photofied_flag = true
    end

    def photos_repository
      @photos_repository ||= FileUtils.mkdir_p File.join(Rails.root, "photofy", self.name)
    end

    #Collects valid photo formats specific to photo fields
    def collect_photo_formats(photo_field, options)
      if options.is_a?(Hash)
        @photo_formats ||= {}
        @photo_formats[photo_field] = options[:formats].is_a?(Array) ? options[:formats].collect { |x| x.starts_with?(".") ? x : ".#{x}" } : [".jpeg", ".jpg", ".gif", ".png", ".bmp"]
      else
        raise 'InvalidArguments'
      end
    end

  end

end

ActiveRecord::Base.send(:include, Photofy)
