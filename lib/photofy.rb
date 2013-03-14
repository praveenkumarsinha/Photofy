begin
  require "RMagick"
rescue Exception => e
  puts "Unable to load 'RMagick' for after_photofy methods"
end

module Photofy
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    attr_accessor :photofield_flag
    attr_accessor :photo_field
    attr_accessor :photo_repository
    attr_accessor :photo_formats

    #Generates photo field from photo_field argument which can be used to store a post processed image(using rmagick) of originally uploaded.
    #Takes two arguments:
    #1. field name
    #2. Proc with rmagick img object
    #return value should be an object of rmagick's image object
    #
    #Example usage..
    #after_photofy :stamp, Proc.new{|img| img.scale(25, 25)}
    #will give a 'stamp' attribute which on save of main photo filed will scale it to 25 x 25 dimesnions
    #after_photofy :portfolio, Proc.new{|img| img.scale(150, 250)}
    #will give a 'portfolio' attribute which on save of main photo filed will scale it to 150 x 250 dimesnions
    def after_photofy(photo_field, p = Proc.new { |img| puts "Rmagick image: #{img.inspect}" })
      define_method "#{photo_field}" do
        File.exist?(send("#{photo_field}_path")) ? File.read(send("#{photo_field}_path")) : nil
      end

      define_method "#{photo_field}_path" do
        directoy_path = FileUtils.mkdir_p File.join(self.class.photo_repository, self.class.photo_field.to_s)
        File.join(directoy_path, "#{photo_field}.jpg")
      end

      define_method "process_n_save_#{photo_field}" do
        begin
          mphoto_f = self.class.photo_field
          if File.exist?(send("#{mphoto_f}_path"))
            img = Magick::Image.read(send("#{mphoto_f}_path")).first # path of Orignal image that has to be worked upon
            img = p.call(img)
            img.write(send("#{photo_field}_path"))
          end
        rescue Exception => e
          puts "Unable to process_n_save_#{photo_field} due to #{e.message}"
          e.backtrace.each { |trace| puts trace }
        end
      end

      define_method "destroy_#{photo_field}" do
        File.delete(send("#{photo_field}_path")) if File.exist?(send("#{photo_field}_path"))
      end

      send(:after_save, "process_n_save_#{photo_field}")
      send(:after_destroy, "destroy_#{photo_field}")
    end

    #Getter to check if model is enabled with photofied
    def is_photofield?
      @photofield_flag.nil? ? false : @photofield_flag
    end

    def register_callbacks
      send(:after_save, "#{photo_field}_store!")
      send(:after_destroy, "#{photo_field}_destroy!")
    end

    #Generates photo filed from photo_field arguments and provides methods like
    #if photo_filed is "collage" then it provides methods on top of it as
    #collage >> Getter,
    #collage =  >> Setter. Accepted inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(format validation is ignored),
    #collage_path >> Getter of filepath,
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk
    def photofy(photo_filed, options = {})
      if options.is_a?(Hash)
        @photo_formats = options[:formats].is_a?(Array) ? options[:formats].collect { |x| x.starts_with?(".") ? x : ".#{x}" } : [".bmp", ".jpg", ".jpeg"]
      else
        raise "InvalidArguments"
      end

      @photo_field = photo_filed

      register_callbacks

      define_method "#{@photo_field}" do
        @file_buffer.nil? ? (send("#{self.class.photo_field}_persisted?") ? File.read(send("#{self.class.photo_field}_path")) : nil) : @file_buffer
      end

      define_method "#{@photo_field}=" do |file_upload|
        if file_upload.class == ActionDispatch::Http::UploadedFile
          return false unless self.class.photo_formats.include?(File.extname(file_upload.original_filename).downcase)
          @file_buffer = File.read(file_upload.path)
        elsif file_upload.class == File
          return false unless self.class.photo_formats.include?(File.extname(file_upload.path).downcase)
          @file_buffer = file_upload.read
        elsif file_upload.class == String
          #return false unless self.class.photo_formats.include?(File.extname(file_upload).downcase)
          @file_buffer = file_upload
        end
      end

      define_method "#{@photo_field}_path" do
        directoy_path = FileUtils.mkdir_p File.join(self.class.photo_repository, self.class.photo_field.to_s)
        File.join(directoy_path, self.send(self.class.primary_key).to_s)
      end

      define_method "#{@photo_field}_persisted?" do
        (@file_buffer.nil? and File.exist?(send("#{self.class.photo_field}_path")))
      end

      define_method "#{@photo_field}_store!" do
        return unless self.class.is_photofield?
        unless @file_buffer.nil?
          File.open(send("#{self.class.photo_field}_path"), "wb+") { |f| f.puts(@file_buffer) }
          @file_buffer = nil
        end
      end

      define_method "#{@photo_field}_destroy!" do
        return unless self.class.is_photofield?
        @file_buffer = nil
        File.delete(send("#{self.class.photo_field}_path")) if File.exist?(send("#{self.class.photo_field}_path"))
      end

      @photofield_flag = true
    end

    def photo_repository
      @photo_repository ||= FileUtils.mkdir_p File.join(Rails.root, "photofied", self.name)
    end

  end

end

ActiveRecord::Base.send(:include, Photofy)
