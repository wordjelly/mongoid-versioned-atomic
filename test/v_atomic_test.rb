require 'test_helper'
 
class CoreExtTest < ActiveSupport::TestCase

  def setup
    User.delete_all
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



  def test_versioned_upsert
    u = User.new
    u.name = "bhargav"
    u.email = "bhargav.r.raut@gmail.com"
    u.versioned_create

    ##update
    updated_doc = User.versioned_upsert({"_id" => u.id,"version" => u.version},{"$set" => {"email" => "b.raut@gmail.com"}})
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
    User.versioned_upsert({"_id" => a.id, "version" => a.version},{"$set" => {"email" => "kkk@gmail.com"}},false)

    a.name = "changed_name"
    a.versioned_update

    ##if the update fails, if there is a validation error, or the document is not persisted, then 

    assert_equal false, a.op_success, "the op should have failed"

  end

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

  def test_image_versioned_create

    a = User.new
    a.image = File.new("/home/bhargav/Github/mongoid_versioned_atomic/test/dummy/app/assets/images/facebook.png")
    a.name = "bhargav"
    a.email = "test@gmail.com"
    
    a.versioned_create

  end

  def test_bypass_versioning_on_update

  end


  def test_merging_optional_update_hash_on_update

  end


end