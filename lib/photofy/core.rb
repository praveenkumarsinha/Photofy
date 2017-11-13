module Photofy
  module Core
    mattr_accessor :photofied_flag
    mattr_accessor :photo_fields
    mattr_accessor :photo_formats

    #Getter to check if model is enabled with file_folder
    def is_photofied?
      @@photofied_flag.nil? ? false : @@photofied_flag
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
    def after_photofy(parent_photo_field, photo_field, proc = Proc.new {|img| puts "Rmagick image: #{img.inspect}"})
      photofy(photo_field, image_processor: proc, parent_photo_field: parent_photo_field)
    end

    #Example
    #photofy(:door)
    #photofy(:door, message: "Some message to show as error when invalid file(w.r.t format) will be used in setter/assignment method")
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
    #collage_s3publicpath >> Public aws s3 url provider if (aws s3 is used as storage)
    #collage_path_to_write >> File path of assignment to write (specific to writing. Used internally),
    #collage_persisted? >> true if provided file/data is stored on disk,
    #collage_store! >> to store provided  file/data on disk,
    #collage_destroy! >> to store destroy stored file/data from disk
    #collage_mark_for_deletion >> to read if field is marked for deletion
    #collage_mark_for_deletion = (true||1) >> to mark delete which will be carried on after save
    #
    #Options:
    #image_processor: a proc for image processing like Proc.new { |img| img.scale(25, 25) }
    #parent_photo_field: a parent photo field name to be used as source
    def photofy(photo_field, options = {})
      (options ||={})[:message] ||= 'not from valid set of allowed file types'

      collect_photo_formats(photo_field, options)

      self.validate "validate_#{photo_field}_field".to_sym

      @@photo_fields ||=[]
      @@photo_fields << photo_field

      define_method "validate_#{photo_field}_field" do
        (@photo_fields_errors ||={}).each do |field, message|
          errors.add(field.to_sym, message)
        end
      end

      define_method 'initialize_photo_buffers' do
        @photo_file_buffer ||= {}
        @photo_file_ofn ||= {}
        @photo_file_delete_marker ||= {}
      end

      define_method "#{photo_field}_path" do
        directory_path = FileUtils.mkdir_p File.join(self.class.photos_repository, photo_field.to_s)
        if s3_connected?
          _path = File.join(directory_path, self.send(self.class.primary_key).to_s)
          _path.gsub!(/^#{Rails.root}\//, "")

          (_s3_objects = s3_bucket.objects.with_prefix("#{_path}_")).count > 0 ? _s3_objects.collect(&:key)[0] : ''
        else
          (guessed_file = Dir[File.join(directory_path, "#{self.send(self.class.primary_key).to_s}_*")].first).nil? ?
              '' : guessed_file.to_s
        end
      end

      define_method "#{photo_field}_s3publicpath" do
        s3_bucket.objects[send("#{photo_field}_path")].url_for(:read).try(:to_s) if send("#{photo_field}_persisted?")
      end if s3_connected?

      define_method "#{photo_field}_path_to_write" do |overload_dir = nil|
        directoy_path = FileUtils.mkdir_p File.join(self.class.photos_repository, photo_field.to_s, overload_dir.to_s)
        _path = File.join(directoy_path, "#{self.send(self.class.primary_key).to_s}#{(@photo_file_ofn[photo_field].nil?) ? "_" : "_#{@photo_file_ofn[photo_field]}" }")
        _path.gsub!(/^#{Rails.root}\//, "") if s3_connected?
        _path
      end

      #Defining getter
      define_method "#{photo_field}" do
        send('initialize_photo_buffers')

        if @photo_file_buffer[photo_field].nil?
          if s3_connected?
            if send("#{photo_field}_persisted?")
              _file = nil
              file = Tempfile.new('foo', :encoding => 'ascii-8bit')
              s3_bucket.objects[send("#{photo_field}_path")].read {|chunk| file.write(chunk)}
              file.rewind
              _file = file.read
              file.close
              file.unlink # deletes the temp file
              _file
            else
              nil
            end
          else
            send("#{photo_field}_persisted?") ? File.read(send("#{photo_field}_path")) : nil
          end
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
          unless self.class.photo_formats[photo_field].include?(File.extname(file_upload.original_filename).downcase)
            (@photo_fields_errors ||= {})[photo_field.to_sym] = options[:message]
            return false
          else
            (@photo_fields_errors ||= {}).delete(photo_field.to_sym)
          end
          @photo_file_buffer[photo_field] = File.read(file_upload.path)
          @photo_file_ofn[photo_field] = File.basename(file_upload.original_filename)

        elsif file_upload.class == File
          unless self.class.photo_formats[photo_field].include?(File.extname(file_upload.path).downcase)
            (@photo_fields_errors ||= {})[photo_field.to_sym] = options[:message]
            return false
          else
            (@photo_fields_errors ||= {}).delete(photo_field.to_sym)
          end
          @photo_file_buffer[photo_field] = file_upload.read
          @photo_file_ofn[photo_field] = File.basename(file_upload.path)

          file_upload.rewind
        elsif file_upload.class == String
          file_upload_processed = file_upload.strip.chomp

          # For handling base 64 encoded image
          if file_upload_processed.match(/\Adata:([-\w]+\/[-\w\+\.]+)?;base64,/)
            file_upload_parts = file_upload_processed.match(/\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m) || []
            extension = Mime::Type.lookup(file_upload_parts[1]).symbol.to_s

            unless self.class.photo_formats[photo_field].include?(".#{extension}")
              (@photo_fields_errors ||= {})[photo_field.to_sym] = options[:message]
              return false
            else
              (@photo_fields_errors ||= {}).delete(photo_field.to_sym)
            end

            @photo_file_buffer[photo_field] = Base64.decode64(file_upload_parts[2])
            @photo_file_ofn[photo_field] = "#{SecureRandom.uuid}.#{extension}"

          else
            @photo_file_buffer[photo_field] = file_upload

          end

        end

        file_upload
      end

      define_method "#{photo_field}_persisted?" do
        send('initialize_photo_buffers')
        if s3_connected?
          directory_path = FileUtils.mkdir_p File.join(self.class.photos_repository, photo_field.to_s)
          _path = File.join(directory_path, self.send(self.class.primary_key).to_s)
          _path.gsub!(/^#{Rails.root}\//, "")

          (@photo_file_buffer[photo_field].nil? and ((s3_bucket.objects.with_prefix("#{_path}_")).count > 0))
        else
          (@photo_file_buffer[photo_field].nil? and File.file?(send("#{photo_field}_path")))
        end
      end

      define_method "#{photo_field}_store" do |proc, parent_photo_field|
        return unless self.class.is_photofied?

        send('initialize_photo_buffers')

        #Loading content from parent_photo_field if specified
        unless parent_photo_field.nil?
          if s3_connected?
            unless send("#{parent_photo_field}_path").empty?
              _parent_file_path = send("#{parent_photo_field}_path")
              _temp_file_path = File.join(Rails.root, File.basename(_parent_file_path))
              file = File.open(_temp_file_path, 'wb')
              s3_bucket.objects[_parent_file_path].read {|chunk| file.write(chunk)}
              file.close
              file = File.open(_temp_file_path)
              send("#{photo_field}=", file)
              file.close
              File.delete(file.path)
            end
          else
            send("#{photo_field}=", File.open(send("#{parent_photo_field}_path"))) unless send("#{parent_photo_field}_path").empty?
          end
        end

        unless @photo_file_buffer[photo_field].nil?

          if s3_connected?
            s3_bucket.objects[send("#{photo_field}_path")].try(:delete) if (not send("#{photo_field}_path").empty?) and (s3_bucket.objects.with_prefix(send("#{photo_field}_path")).count > 0)
            s3_bucket.objects[send("#{photo_field}_path_to_write")].write(@photo_file_buffer[photo_field])

            unless proc.nil?
              file = Tempfile.new('foo', :encoding => 'ascii-8bit')
              s3_bucket.objects[send("#{photo_field}_path")].read {|chunk| file.write(chunk)}
              file.rewind

              img = Magick::Image.read(file.path).first
              img = proc.call(img)
              s3_bucket.objects[send("#{photo_field}_path_to_write")].write(img.to_blob)

              file.close
              file.unlink # deletes the temp file
            end
          else
            File.delete(send("#{photo_field}_path")) if File.exist?(send("#{photo_field}_path")) #Clearing any existing file at the path
            File.open(send("#{photo_field}_path_to_write"), "wb+") {|f| f.puts(@photo_file_buffer[photo_field])}

            unless proc.nil?
              FileUtils.copy(send("#{photo_field}_path_to_write"), send("#{photo_field}_path_to_write", "original_source"))
              img = Magick::Image.read(send("#{photo_field}_path")).first
              img = proc.call(img)
              img.write(send("#{photo_field}_path_to_write"))
            end
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
        if s3_connected?
          s3_bucket.objects[send("#{photo_field}_path")].try(:delete)
        else
          File.delete(send("#{photo_field}_path")) if File.exist?(send("#{photo_field}_path"))
        end
      end

      # to read if photo_field is marked for deletion
      define_method "#{photo_field}_mark_for_deletion" do
        (@photo_file_delete_marker ||= {})[photo_field.to_sym] rescue nil
      end

      # to mark photo_field for deletion upon save(highest precedence than setter)
      define_method "#{photo_field}_mark_for_deletion=" do |value|
        (@photo_file_delete_marker ||= {})[photo_field.to_sym] = value
      end

      # Deletes all photo_fields marked for deletion
      define_method 'delete_marked_photo_fields' do
        (@photo_file_delete_marker ||= {}).each do |photo_field, marked|
          if marked == true or marked.to_i > 0
            send("#{photo_field}_destroy!")
            @photo_file_delete_marker[photo_field] = false
          end
        end
      end

      send(:after_save, "#{photo_field}_store!".to_sym)
      send(:after_save, :delete_marked_photo_fields) #Makes it last ro execute among callbacks hence it deletes (with utmost importance)
      send(:after_destroy, "#{photo_field}_destroy!".to_sym)

      @@photofied_flag = true
    end

    def photos_repository
      FileUtils.mkdir_p(File.join(Rails.root, "photofy", self.name.underscore))[0]
    end

    #Collects valid photo formats specific to photo fields
    def collect_photo_formats(photo_field, options)
      if options.is_a?(Hash)
        @@photo_formats ||= {}
        @@photo_formats[photo_field] = options[:formats].is_a?(Array) ? options[:formats].collect {|x| x.starts_with?(".") ? x : ".#{x}"} : [".jpeg", ".jpg", ".gif", ".png", ".bmp"]
      else
        raise 'InvalidArguments'
      end
    end

  end
end