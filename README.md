# MongoidVersionedAtomic

## What this gem does
    This gem extends mongoid with three ATOMIC methods: 
a. versioned_create : creates a document instance, optionally accepts a query, incrementing the document version on create.
b. versioned_update : updates all fields on a document instance, incrementing the document version on success.
c. versioned_upsert : given a query and and update hash, increments the document version on successfull update, or creates the documetn if no document matches the query params.

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
  
  field :name, type: string
  field :confirmation_token, type: string
end
```
    
### Create

#### Create without a query
```
d = User.new
d.name = "rini"
d.versioned_create
d.op_success
#=> true
d.version
#=> 1
```
#### Create with an optional query(CREATE WHERE)
This method should be used with queries with caution, since it will overwrite a matching record with all the attributes of the current instance.

Suppose you want to create a document ONLY IF there is no document with the confirmation token of the current instance.
We can do this atomically by providing the following "$ne" query.

```
d = User.new
d.name = "rini"
d.confirmation_token = "test_token"
d.versioned_create({"$ne" => {"confirmation_token" => "test_token"}})
d.op_success
#=> true
d.version
#=> 1
```

Use this method when you receive a call to your app's create method.
It will fail if the version of the document is not 0.

### Update

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

Use this method when you receive a call to your app's update action.
It will fail if the document version is less than 1.

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


  
