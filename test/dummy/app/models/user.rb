require "mongoid_paperclip"
class User
  include Mongoid::Document
  include MongoidVersionedAtomic::VAtomic
  include Mongoid::Paperclip
  has_mongoid_attached_file :image
  


  validates_attachment_content_type :image, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]


  field :name, type: String
  field :email, type: String
  field :dummy, type: String
  field :before_create_field, type: Integer, default: 0
  field :after_create_field, type: Integer, default: 0
  field :before_update_field, type: Integer, default: 0
  field :after_update_field, type: Integer, default: 0
  field :likes, type: Integer, default: 0
  validates :name, presence:{message: "There should be a user name"}
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

  before_create :do_before_create
  after_create :do_after_create
  before_update :do_before_update
  after_update :do_after_update

  def self.image_attributes
    ["image_file_name","image_fingerprint","image_content_type","image_file_size","image_updated_at"]
  end

  private

  def do_before_create
  	self.before_create_field = 1
  end

  def do_after_create
    
  	self.after_create_field = 1 
  end

  def do_before_update
  	self.before_update_field = 1
  end

  def do_after_update
  	self.after_update_field = 1
  end

end
