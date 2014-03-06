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
    attr_accessor :photofy_attr
    attr_accessor :photo_repository

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
    #and also provide 're_photofy_portfolio!'(Proc.new{|img| img.scale(10, 20)}) to perform operation on other user defined events
    def after_photofy(photo_field, p = Proc.new { |img| puts "Rmagick image: #{img.inspect}" })
      #define_method "#{photo_field}" do
      #  File.exist?(send("#{photo_field}_path")) ? File.read(send("#{photo_field}_path")) : nil
      #end

      #define_method "#{photo_field}?" do
      #  send("#{photo_field}").nil? ? false : true
      #end

      #define_method "#{photo_field}_cover_path" do
      #  directoy_path = FileUtils.mkdir_p File.join(self.class.photo_repository, photo_field.to_s)
      #  File.join(directoy_path, "#{photo_field}_#{self.send(self.class.primary_key)}.jpg")
      #end

      define_method "re_photofy_#{photo_field}!" do |proc|
        send("process_n_save_#{photo_field}", proc)
      end

      define_method "process_and_save_#{photo_field}!" do
        send("process_n_save_#{photo_field}", p)
      end

      define_method "process_n_save_#{photo_field}" do |proc|
        begin
          if File.exist?(send("#{photo_field}_path"))
            img = Magick::Image.read(send("#{photo_field}_path")).first # path of Orignal image that has to be worked upon
            img = proc.call(img)
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

      send(:after_save, "process_and_save_#{photo_field}!")
      send(:after_destroy, "destroy_#{photo_field}")
    end

    #Getter to check if model is enabled with photofied
    def is_photofield?
      @photofield_flag.nil? ? false : @photofield_flag
    end

    def register_callbacks(photo_filed)
      send(:after_save, "#{photo_filed}_store!")
      send(:after_destroy, "#{photo_filed}_destroy!")
    end

    #Generates photo filed from photo_field arguments and provides methods like
    #if photo_filed is "collage" then it provides methods on top of it as
    #collage >> Getter,
    #collage? >> Returns true if collage is having value other than nil else false,
    #collage =  >> Setter. Accepted inputs are file upload(ActionDispatch::Http::UploadedFile), filer handle and String(format validation is ignored),
    #collage_path >> Getter of filepath,
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk
    def photofy(photo_filed, options = {})
      if options.is_a?(Hash)
        @photofy_attr ||={}
        @photofy_attr[photo_filed] ||={}
        @photofy_attr[photo_filed][:formats] = options[:formats].is_a?(Array) ? options[:formats].collect { |x| x.starts_with?(".") ? x : ".#{x}" } : [".bmp", ".jpg", ".jpeg", '.png']
      else
        raise "InvalidArguments"
      end
      register_callbacks(photo_filed)

      define_method "#{photo_filed}" do
        self.class.photofy_attr[photo_filed][:file_buffer].nil? ?
            (send("#{photo_filed}_persisted?") ? File.read(send("#{photo_filed}_path")) : nil)
            : self.class.photofy_attr[photo_filed][:file_buffer]
      end

      define_method "#{photo_filed}?" do
        send("#{photo_filed}").nil? ? false : true
      end

      define_method "#{photo_filed}=" do |file_upload|
        if file_upload.class == ActionDispatch::Http::UploadedFile
          return false unless self.class.photofy_attr[photo_filed][:formats].include?(File.extname(file_upload.original_filename).downcase)
          self.class.photofy_attr[photo_filed][:file_buffer] = File.read(file_upload.path)
        elsif file_upload.class == File
          return false unless self.class.photofy_attr[photo_filed][:formats].include?(File.extname(file_upload.path).downcase)
          self.class.photofy_attr[photo_filed][:file_buffer] = file_upload.read
        elsif file_upload.class == String
          #return false unless self.class.photo_formats.include?(File.extname(file_upload).downcase)
          self.class.photofy_attr[photo_filed][:file_buffer] = file_upload
        end
      end

      define_method "#{photo_filed}_path" do
        directoy_path = FileUtils.mkdir_p File.join(self.class.photo_repository, photo_filed.to_s)
        File.join(directoy_path, self.send(self.class.primary_key).to_s)
      end

      define_method "#{photo_filed}_persisted?" do
        (self.class.photofy_attr[photo_filed][:file_buffer].nil? and File.file?(send("#{photo_filed}_path")))
      end

      define_method "#{photo_filed}_store!" do
        return unless self.class.is_photofield?
        unless self.class.photofy_attr[photo_filed][:file_buffer].nil?
          File.open(send("#{photo_filed}_path"), "wb+") { |f| f.puts(self.class.photofy_attr[photo_filed][:file_buffer]) }
          self.class.photofy_attr[photo_filed].delete(:file_buffer)
        end
      end

      define_method "#{photo_filed}_destroy!" do
        return unless self.class.is_photofield?
        self.class.photofy_attr[photo_filed].delete(:file_buffer)
        File.delete(send("#{photo_filed}_path")) if File.exist?(send("#{photo_filed}_path"))
      end

      @photofield_flag = true
    end

    def photo_repository
      @photo_repository ||= FileUtils.mkdir_p File.join(Rails.root, "photofied", self.name)
    end

  end

end

ActiveRecord::Base.send(:include, Photofy)
