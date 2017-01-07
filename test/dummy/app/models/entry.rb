class Entry
  include Mongoid::Document
  field :name, type: String
  field :description, type: String
  field :parent_thing_id, type: BSON::ObjectId
  ##entries. will be stored in elasticsearch and they will also have names.
  ##here we can have elasticsearch model and callbacks. 
  after_save do |document|  	
	   q = Thing.versioned_upsert_one({"_id" => document.parent_thing_id},{"$set" => {"entries.#{document.id.to_s}" => Time.now.to_i}},Thing,false,false,false)
  end
end
