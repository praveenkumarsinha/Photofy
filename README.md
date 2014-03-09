## Photofy
A simple ruby gem providing photo fields to rails model

## Installation
Add this line to your application's Gemfile:

`gem 'zero_authorization'`

And then execute:

`$ bundle`

Or install it yourself as:

`$ gem install zero_authorization`


## Usage
Add photo field(s) to model by adding lines like
* `photofy(:collage)`
> * `collage` : Getter,
> * `collage?` : Returns true if assignment is having value other than nil else false,
> * `collage =` : Setter. Acceptable inputs are file upload(ActionDispatch::Http::UploadedFile), file and String(format validation is ignored),
> * `collage_path` : File path of assignment,
> * `collage_persisted?` : Gives true if provided file/data is stored on disk,
> * `collage_store!` : To store provided file/data on disk,
> * `collage_destroy!` : To destroy stored file/data from disk

* `photofy(:collage_sec, {parent_photo_field: :collage})`
> * Automatically creates a collage_sec photo field from :collage parent field

* `photofy(:stamp, {image_processor: Proc.new { |img| img.scale(25, 25) }})`
> * Process image to scale(refer imagemagick/rmagick for other image manipulations) of 25x25px when image is saved.

* `after_photofy :collage, :post_card, Proc.new { |img| img.scale(450, 200) }`
> * Creates 'post_card' photo field by taking source from 'collage' and scaling it to 450x200px.

