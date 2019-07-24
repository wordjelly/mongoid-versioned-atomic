require 'test_helper'
 
class CoreExtTest < ActiveSupport::TestCase

  def setup
    User.delete_all
  end 


  def test_cross_model_callbacks
    t1 = Thing.new
    t1.versioned_create
    e = Entry.new
    e.parent_thing_id = t1.id
    e.save
    t1.reload
    assert_equal(1, t1.entries.size, "the entry id was saved to thing entries")
  end

  def test_versioned_upsert_one_with_set_on_insert
    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bhargav.r.raut@gmail.com"
    User.versioned_upsert_one({"_id" => a1.id},{"$setOnInsert" => {"name" => "cat"}},User)
    a1_from_db = User.find(a1.id)
    assert_equal 1, a1_from_db.version, "set on insert should work with version operator." 

  end


  def test_versioned_create_when_document_already_exists

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bhargav.r.raut@gmail.com"
    a1.versioned_create
    assert_equal true, a1.op_success, "this op should succeed."

    a2 = User.new
    a2.name = "bb"
    a2.email = "bhargav.r.raut@gmail.com"
    a2.versioned_create({"email" => a2.email})
    assert_equal false, a2.op_success, "this op should not succeed"
    assert_nil a2.upserted_id,"no new doc should be upserted"
    assert_equal 1, a2.matched_count, "it should match an existing doc"
  end


  def test_versioned_upsert_one_returns_a_mongoid_document

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bhargav.r.raut@gmail.com"
    a1.versioned_create

    ret = User.versioned_upsert_one({"_id" => a1.id},{"$set" => {"name" => "roxanne"}},User)

    

    assert_equal true, (ret.methods.include? :attributes), "it should return a mongoid document"

  end

  def test_versioned_upsert_one_increments_version_if_doc_found_but_doesnt_affect_other_docs

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bhargav.r.raut@gmail.com"
    a1.versioned_create

    a2 = User.new
    a2.name = "aditya"
    a2.email = "aditya@gmail.com"
    a2.versioned_create

    User.versioned_upsert_one({"_id" => a1.id},{"$set" => {"name" => "roxanne"}},User)

    a1_from_db = User.find(a1.id)
    a2_from_db = User.find(a2.id)

    assert_equal 2, a1_from_db.version , "the document version should be 2"
    assert_equal "roxanne", a1_from_db.name, "the name should have been updated"
    assert_equal 1, a2_from_db.version, "the other documents should not have been affected"
    assert_equal "aditya",a2_from_db.name, "the name of the other document should be the same as before."

  end

  def test_versioned_upsert_one_increments_version_if_doc_created

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bh@gmail.com"
    set_hash = {}
    a1.as_document.keys.each do |k|
      if k!= "version" 
        set_hash[k] = a1.as_document[k]
      end
    end
    puts "set hash is:"
    puts set_hash.to_s
    User.versioned_upsert_one({"_id" => a1.id},{"$set" => set_hash},User)

    persisted_doc = User.find(a1.id)
    assert_equal 1, persisted_doc.version, "the persisted document version should be one."


  end


  def test_bypass_versioning_gives_op_success_in_versioned_update

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bh@gmail.com"
    a1.versioned_create

    a1 = User.find(a1.id)
    a1.name = "updated name"
    a1.versioned_update({},true,{},false)

    updated_doc = User.find(a1.id)
    assert_equal 1, updated_doc.version , "the persisted document version should be one, since we bypassed versioning."
    assert_equal "updated name", updated_doc.name, "the persisted document name should be the updated name"
    assert_equal true, a1.op_success, "the operation should still be successfull"

  end

  def test_versioned_upsert_one_does_not_affect_all_docs_if_query_is_empty

    a1 = User.new
    a1.name = "bhargav"
    a1.email = "bhargav.r.raut@gmail.com"
    a1.versioned_create

    persisted_document = User.find(a1.id)

    a = User.versioned_upsert_one({},{"$set" => {"name" => "dog"}},User)
    
    assert_equal 1, User.count, "number of documents should not change"
    assert_equal 1, persisted_document.version, "the version of the only existing document should be 1"
    assert_equal "bhargav", persisted_document.name, "the name of the persisted document should be the same"

  end


  ##if the document that is searched for is found, then the setOnInsert part will not be executed, but any "inc" keys in the update hash will be.
  ##we test that this does not happen.
  def test_does_not_increment_version_of_all_existing_document_on_create

   a = User.new
   a.name = "bhargav"
   a.email = "u@gmail.com"
   a.versioned_create

   a2 = User.new
   a2.name = "bb"
   a2.email = "bb@gmail.com"
   a2.versioned_create

   ##here there will be a record with this id already found, so nothing new will be inserted.
   ##but we assert that the versions of all the other records in the database are still maitained at one.
   u1 = User.new
   u1.name = "b2"
   u1.email = "b2@gmail.com"
   u1.versioned_create({"_id" => a.id})

   assert_equal 2, User.count, "there should be only two users"
   User.all.each do |user|
    assert_equal 1, user.version, "the version of all docs in the database should be one."
   end


  end

  def test_query_in_create

    u = User.new
    u.name = "bhargav"
    u.email = "u@gmail.com"
    u.versioned_create

    u1 = User.new
    u1.name = "aditya"
    u1.email = "s@gmail.com"
    u1.versioned_create({"$or" =>
     [
      {"_id" => u1.id},
      {"name" => "bhargav"}
     ]
   })

    assert_equal 1, User.count, "the user count should be one"

  end


  def test_create_two_users

    u = User.new 
    u.name = "bhargav"
    u.email = "t@gmail.com"
    u.versioned_create
    

    u1 = User.new
    u1.name = "dog"
    u1.email = "d@gmail.com"
    u1.versioned_create

    assert_equal 1, u.version, "the version of the first user should be one"
    assert_equal 1, u1.version, "the version of the second user should be one"

  end

  def test_versioned_create
  	u = User.new
  	u.name = "bhargav"
  	u.email = "raut@gmail.com"
    u.versioned_create

    ##assert that attributes are set on the instance itself.
  	assert_equal 1, User.count, "the user count should be one"
    assert_equal 1, u.version, "the version should have incremented"
    assert_equal "bhargav", u.name, "the name should have been persisted"
    assert_equal "raut@gmail.com",u.email, "the email should have been persisted"
    assert_equal true, u.op_success, "the operation should be successfull"
      
    ##assert that attributes are set on the document in the database
    u = User.find(u.id)
    assert_equal 1, u.version, "(db)the version should have incremented"
    assert_equal "bhargav", u.name, "(db)the name should have been persisted"
    assert_equal "raut@gmail.com",u.email, "(db)the email should have been persisted"
        
  end

  def test_versioned_create_should_return_doc_counts
    a1 = User.new
    a1.name = "bhargav"
    a1.email = "rrphotosoft@gmail.com"
    a1.versioned_create
    assert_equal 0,a1.matched_count,"should not have any matched documents"
    assert_not_nil(a1.upserted_id,"there should be an upserted id")
  end

  def test_versioned_create_should_return_matched_count_as_one_if_doc_exists
    a1 = User.new
    a1.name = "bhargav"
    a1.email = "rrphotosoft@gmail.com"
    a1.versioned_create
    
    a2 = User.new
    a2.name = "bhargav"
    a2.email = "rrphotosoft@gmail.com"
    a2.versioned_create({"email" => "rrphotosoft@gmail.com"})
    assert_equal 1,a2.matched_count,"the matched count should be one."
    assert_equal 0,a2.modified_count, "the modified count should be zero"
    assert_nil a2.upserted_id,"the upserted id should be nil"
  end


  def test_versioned_update_without_providing_dirty_fields
  	u = User.new
  	u.name = "bhargav"
  	u.email = "bhargav.r.raut@gmail.com"
  	u.versioned_create

    ##now update one field.
    u.email = "c@gmail.com"
  	 

    ##assert that attributes are set on the provided instance.
    u.versioned_update
  	assert_equal 2, u.version, "the document version is 2"
  	assert_equal "c@gmail.com", u.email, "the document email should have updated"
    assert_equal true, u.op_success, "the operation should be successfull"
     

    ##assert that the attributes are set on the document in the database
    u = User.find(u.id)
    assert_equal 2,u.version,"(db)the version should be 2"
    assert_equal "c@gmail.com",u.email, "(db)the document email should have updated"

  end



  def test_versioned_update_providing_dirty_fields
    u = User.new
    u.name = "bhargav"
    u.email = "bhargav.r.raut@gmail.com"
    u.versioned_create

    ##update two fields
    u.email = "c@gmail.com"
    u.name = "doggy"

    ##provide only one field as dirty
    u.versioned_update({"email" => 1})
    
    ##assert that the attributes are set on the present instance.
    assert_equal 2, u.version, "the document version is 2"
    assert_equal "c@gmail.com", u.email, "the document email should have updated"
    assert_equal "bhargav", u.name, "the document name should not have updated, since it was not provided as a dirty field, even if it has changed"
    assert_equal true, u.op_success, "the operation should be successfull"
     
    
    ##assert that the document in the database is updated.
    u = User.find(u.id)
    assert_equal 2,u.version,"(db)the version should be 2"
    assert_equal "c@gmail.com",u.email, "(db)the document email should have updated"
    assert_equal "bhargav", u.name, "(db)the document name should not have updated, since it was not provided as a dirty field, even if it has changed"

  end


  def test_invalid_documents_are_not_created
    
    u = User.new
    u.email = "horse"
    u.name = "caca"
    u.versioned_create

    
    ##assert that the instance does not contain the invalid fields
    assert_equal false, u.op_success, "the op should fail"

    
    ##assert that there is no such document in the database
    assert_equal 0, User.count, "(db)there should be no such record in the datbase"

    
    ##assert that the error is present on the instance.
    assert_not_empty u.errors.full_messages, "there are errors"

    
  end



  def test_versioned_upsert_one
    u = User.new
    u.name = "bhargav"
    u.email = "bhargav.r.raut@gmail.com"
    u.versioned_create

    ##update
    updated_doc = User.versioned_upsert_one({"_id" => u.id,"version" => u.version},{"$set" => {"email" => "b.raut@gmail.com"}},User)
    u = User.find(u.id)
    assert_equal updated_doc["email"], "b.raut@gmail.com","it should return the updated document"
    assert_equal u.email, "b.raut@gmail.com","the mongoid document should be updated"

  end



  def test_before_create_callbacks

    u = User.new
    u.name = "bhargav"
    u.email = "b@gmail.com"
    u.versioned_create
    u = User.find(u.id)
    assert_equal 1,u.before_create_field, "the before create callback should fire"

  end

 


  def test_after_create_callbacks

    u = User.new
    u.name = "bhargav"
    u.email = "b@gmail.com"
    u.versioned_create
    assert_equal 1, u.after_create_field, "the after create callbacks should fire"

    u = User.find(u.id)
    assert_equal 0, u.after_create_field, "the after create callback should not have persisted anything during the save"

  end


  def test_before_update_self_callbacks
    u = User.new
    u.name = "bhargav"
    u.email = "bhargav.r.raut@gmail.com"
    u.versioned_create
    u.email = "updated_email@gmail.com"
    u.versioned_update 
    assert_equal 2, u.version, "the document version is 2"
    assert_equal "updated_email@gmail.com", u.email, "the document email should be cacophony"
    assert_equal 1, u.before_update_field, "the before update callback should have fired"

  end


  def test_version_conflict

    a = User.new
    a.name = "bhargav"
    a.email = "b.r.raut@gmail.com"
    a.versioned_create

    ##now we send an update, but before that we already update it using upsert.
    ##so that we get a version conflict.
    User.versioned_upsert_one({"_id" => a.id, "version" => a.version},{"$set" => {"email" => "kkk@gmail.com"}},User,false)

    a.name = "changed_name"
    a.versioned_update

    ##if the update fails, if there is a validation error, or the document is not persisted, then 

    assert_equal false, a.op_success, "the op should have failed"

  end

=begin
  THESE THREE TESTS HAVE BEEN COMMENTED OUT BECAUSE WE HAVE BLOCKED OUT THE BEFORE_ACTION THAT USED TO PREVIOUSLY FILTER OUT THE VERSION AND OP_SUCCESS FIELDS IF THEY HAD BEEN SET, BUT WE DONT DO THAT ANYMORE, BECAUSE IT LED TO UNPREDICTABLE BEHAVIOUR WHERE FOR EG:
  - FIRST A MODEL IS SAVED USED VERSIONED_CREATE
  - THAT GIVES IT A VERSION
  - THEN YOU MAKE SOME CHANGES ON THAT MODEL AND CALL CONVENTIONAL SAVE ON IT
  - THIS WILL WIPE OUT THE VERSION
  - THEN SUPPOSE YOU AGAIN WANT TO CALL A VERSIONED_CREATE/UPDATE/UPSERT ON THE SAME RECORD
  - IT DOES NOT WORK BECAUSE NOW VERSION TAKES ITS DEFAULT VALUE OF ZERO.
  - TO AVOID THIS PROBLEM, THIS FILTER IS NO LONGER USED, AND HENCE THESE TESTS ARE REDUNDANT.
  - The filter has been commented out in the module.
  def test_version_and_op_success_not_persisted_on_calling_save

    a = User.new
    a.email = "bhargav.r.raut@gmail.com"
    a.name = "bhargav"
    a.version = 10
    a.op_success = true
    a.save


    u = User.find(a.id)

    assert_equal true, a.save, "the document should get saved"
    assert_nil a.version , "the version should be nil"
    assert_nil a.op_success, "the op success should be nil"
    assert_equal a.email, "bhargav.r.raut@gmail.com","the email should have been persisted"

  end

  def test_version_and_op_success_not_persisted_on_calling_create

    q = User.create(:email => "bhargav.r.raut@gmail.com", :name => "ten", :version => 10, :op_success => false)
    assert_nil q.version, "the version should be nil"
    assert_nil q.op_success, "the op success shoudl be nil"
    assert_equal 1, User.count, "there should be one user document"

  end


  def test_version_and_op_success_not_persisted_on_calling_update

    a = User.new
    a.email = "bhargav.r.raut@gmail.com"
    a.name = "bhargav"
    a.save

    a.version = 10
    a.op_success = true
    a.email = "bharg@gmail.com"
    a.update_attributes

    r = User.find(a.id)

    assert_nil a.version, "the version on update should be nil"
    assert_nil a.op_success, "the op success on update should be nil"
    assert_equal a.email, "bharg@gmail.com"
    assert_equal r.email, "bharg@gmail.com"

  end
=end

=begin
  def test_image_versioned_create

    a = User.new
    a.image = File.new("/home/bhargav/Github/mongoid_versioned_atomic/test/dummy/app/assets/images/facebook.png")
    a.name = "bhargav"
    a.email = "test@gmail.com"
    
    a.versioned_create
    assert_not_nil a.image 

  end

  def test_image_versioned_update

    a = User.new
    a.image = File.new("/home/bhargav/Github/mongoid_versioned_atomic/test/dummy/app/assets/images/facebook.png")
    a.name = "bhargav"
    a.email = "vitesse@gmail.com"
    a.versioned_create

    a.image = File.new("/home/bhargav/Github/mongoid_versioned_atomic/test/dummy/app/assets/images/keratoscope.jpg")

    a.versioned_update(Hash[User.image_attributes.zip([])])
    assert_not_nil a.image
  
  end
=end

  def test_bypass_versioning_on_update

    a = User.new
    a.email = "bhargav.r.raut@gmail.com"
    a.name = "bhargav"
    a.versioned_create

    a.name = "changed"
    query,update,options = a.versioned_update({},true)

    assert_equal 1 , a.version, "the version should be one."
    assert_equal "changed", a.name, "the name should have been persisted"
    assert_equal true, query["version"] == nil, "there should be no version parameter in the query."

    a = User.find(a.id)

    assert_equal 1, a.version, "(db) the version in the db should be one"
    assert_equal "changed", a.name, "(db) the name in the db should be one."

  end


  def test_passing_optional_update_hash

    a = User.new
    a.email = "bhargav.r.raut@gmail.com"
    a.name = "bhargav"
    a.versioned_create

    query,options,update = a.versioned_update({},false,{"$inc" => {"likes" => 1}, "$set" => {"name" => "changed"}})

    assert_equal 1, a.likes, "the likes should be one."
    assert_equal "changed",a.name, "the name should be changed"
    assert_equal 2, a.version, "the document version is 1"
    

    a = User.find(a.id)
    assert_equal 1, a.likes, "(db)the likes should be one."
    assert_equal "changed",a.name, "(db)the name should be changed"
    assert_equal 2, a.version, "(db)the document version is 1"    

  end

  def test_passing_optional_update_hash_and_bypass_versioning
    
    a = User.new
    a.email = "bhargav.r.raut@gmail.com"
    a.name = "bhargav"
    a.versioned_create

    query,options,update = a.versioned_update({},true,{"$inc" => {"likes" => 1}, "$set" => {"name" => "changed"}})

    assert_equal 1, a.likes, "the likes should be one."
    assert_equal "changed",a.name, "the name should be changed"
    assert_equal 1, a.version, "the document version is 1"
    assert_equal true, query["version"] == nil, "there should be no version parameter in the query."

    a = User.find(a.id)
    assert_equal 1, a.likes, "(db)the likes should be one."
    assert_equal "changed",a.name, "(db)the name should be changed"
    assert_equal 1, a.version, "(db)the document version is 1"    


  end

end
