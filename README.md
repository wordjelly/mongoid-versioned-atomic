# MongoidVersionedAtomic

## Why
Mongoid does not provide a simple DSL to create or update documents atomically.
Mongoid Versioning support was removed from version 4.0
Mongodb does not have the concept of transactions, so optimistic concurrency control is a necessity.

## Setup

     gem 'mongoid-versioned-atomic', :git => "git://github.com/wordjelly/mongoid-versioned-atomic.git"

## Usage

In your mongoid documents include the following
```
class User
  include Mongoid::Document
  include MongoidVersionedAtomic::VAtomic
  
  ##some dummy fields
  
  field :name, type: string
  field :confirmation_token, type: string
  field :something_else, type: xyz
end
```
    
### Create


```
instance.versioned_create(query={},log=false)
```

The default query is empty.
Inside the method, the id of the instance is added to the query, and the query becomes:

```
query = {"_id" => instance.id}
```
the method searches for an element with the id of the given instance, and if it does not exist, then the instance and all its fields are "upserted". Suppose that even one record with this id exists, no new records will be created.


Example:

```
d = User.new
d.name = "rini"
d.versioned_create
d.op_success
#=> true
d.version
#=> 1

```

#### Create with an optional query.

You can pass in a query to the create call. If you pass in a query, then it will override the internal query mechanism described above. This means that it will not check for the uniqness of the document id, however if an id gets generated that already exists, that will fail due to mongodb's inherent checks.

If a document is found that matches your query, then no new documents will be inserted. On the other hand, if no documents are found matching your query , then the given instance is persisted.

This can be useful for unique checks, without creating unique indexes. Suppose you only want to create a new user if there is no existing user with the current user's name. Then you should do the following:



```
d = User.new
d.name = "dog"
d.versioned_create({"name" => "dog"})
d.version
#=> 1
d1 = User.new
d1.name = "doggus"
##the query will check whether there is any record with the name of "dog" and in that case it will execute the update on that record, but since we have specified the update hash(internal to the method) only using "setOnInsert" no new records are inserted.
d1.versioned_create({"name" => "dog"})
d1.op_success
#=> false
d1.version
#=> 0
```



### Update

```
instance.versioned_update(dirty_fields={},bypass_versioning=false,optional_update_hash={},log=false)
```

This method accepts four arguments:


1.dirty_fields : keys should be names of those fields which are to be updated, defaults to empty, in which case all fields except "id" and "verion" will be added to the "$set" in the update hash.
2.bypass_versioninig : if true, then the version check is not performed while doing the update, and neither is the version incremented.
3.optional_update_hash : this hash can be provided if you want to specify your own update settings, it will override the default "$set" that includes all fields on the instance by default.
4.log : whether you want the method to print out the final command to mongodb. defaults to false.

The query in this case is just the document id , and the document version, both of which are taken from the instance itself. If the document is found, then the update hash is applied to it.

```
d = User.new
d.name = "test"
d.versioned_create
d.op_success
#=> true
d.version
#=> 1

d.name = "updated_name"
d.versioned_update
d.op_success
#=> true
d.version
#=> 2
```


### Atomic Query and Update.
This is a class method. So it will not run callbacks, validations etc.
It sets upsert by default to true.
If the required record is not found, a new one will be created, if found, then the said record will be updated with the 
conditions in the update hash.
The third parameter can be set to true/false to decide whether upsert should be true or false.
```
User.versioned_upsert(
{"confirmation_token" => "abcd"},
{"$set" => {"name" => "already_exists"},
 "$setOnInsert" => {"name" => "new_name"}
},
true
)
```
This method allows you to decide what gets set if the record is new, or already exists.
Since you can provide a update hash.


  
