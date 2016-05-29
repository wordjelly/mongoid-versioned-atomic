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
#### Create with an optional query
Suppose you want to create a new user provided that there is no document in the database with the confirmation token 
"test_token"

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



    
  
