# MongoidVersionedAtomic

## What this gem does
    This gem extends mongoid with three methods: 
    a. versioned_create : creates a document instance, optionally accepts a query, incrementing the document version on create.
    b. versioned_update : updates all fields on a document instance, incrementing the document version on success.
    c. versioned_upsert : given a query and and update hash, increments the document version on successfull update, or creates the documetn if no document matches the query params.

## Why
    Mongoid does not provide a simple DSL to create or update documents atomically.
    Mongoid Versioning support was removed from version 4.0
    Mongodb does not have the concept of transactions, so optimistic concurrency control is a necessity.


  
  
