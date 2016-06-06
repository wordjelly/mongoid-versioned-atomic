module MongoidVersionedAtomic
	module VAtomic

		

		extend ActiveSupport::Concern
	 	
	    included do
	    	field :version, type: Integer, default: 0
	    	field :op_success, type: Boolean
	    	before_save :filter_fields
	    end

	    def self.included(base)
	        base.extend(ClassMethods)
	    end

	    module ClassMethods


	    	##optionally provide upsert value.
	    	##if the version is nil, then version is not used in the query, and upsert will be set to true, the update will execute as long as a document matches the query, or if a document does not match then a new document will be created.
	    	##if the version is provided, then it will be used in the query
	    	##document is not validated, before hand, since there is no document to validate.
	    	##call validate on a mongoid document before hand if you need to.
	    	def versioned_upsert(query={},update={},upsert = true,log=false)
	    		
	    		options = {}

	    		options,update = before_persist(options,update)
	    		
				options[:upsert] = upsert
				
	    		collection.find_one_and_update(query,update,options)

	    	end

	    	##@param options[Hash] -> the options hash for the find_one_and_update method
	    	#@param update[Hash] -> the update hash for the find_one_and_update method
	    	#@param doc_hash[Hash] -> the document as a hash
	    	def before_persist(options,update,bypass_versioning=false)

	    		options[:return_document] = :after

	    		if !bypass_versioning
			 		if update["$inc"].nil?
						update["$inc"] = {
							"version" => 1 }
					else
						update["$inc"]["version"] = 1
					end
				end

				return options,update

	    	end

	    	##given a document, it will update all the changed attributes on self,
			##then returns nothing.
			def after_persist(doc,instance)
					doc.keys.each do |f|
						if f == "version"
							instance.send("#{f}=",doc[f])
						else
							if instance.send("#{f}") != doc[f]
								instance.send("#{f}=",doc[f])
							end
						end
					end
				return true
			end

			##logs
			def log_opts(query,update,options,create_or_update,log)

				if log

					puts "doing-------------------- #{create_or_update}"


					puts "the query is :"
					puts JSON.pretty_generate(query)

					puts "the update is"
					puts JSON.pretty_generate(update)

					puts "the options are"
					puts JSON.pretty_generate(options)
				
				end

			end

	    end

	    # removes "version" and "op_success" fields from the document before save or update, this ensures that these fields can only be persisted by the versioned_create and versioned_update methods.
	    # prevents inadvertent persistence of these fields.
	    #return[nil]
	    def filter_fields
	    
	    	remove_attribute(:version)
	    	remove_attribute(:op_success)
	    	attributes

	    	
	    end


		# creates the document, uses the query parameters provided. Increments the version of the document to 1 on successfull creation. Sets "op_success" to true on successfull creation , otherwise false.

		# @param query[Hash](Optional) : queries can be provided based on the syntax in the mongodb ruby driver api.
		
		# @return true : will return true irrespective of whether the document was created or not.
		
		# @example : in order to check the creation, call [doc.op_success] and if true, then the creation was successfull.
		
		# @logic : 
		# 1. set the op_success to false
		# 2. if the version is 0(default version for a new record), then proceed
		# 3. set the upsert to true, and set the "setonINsert" to an empty hash
		# 4. start the prepare_insert block, this method is defined in the mongoid creatable module
		# 5. call as_document - a mongoid method that returns all the attributes on the document, and then for each of its keys, provided that they are not version or op_success, set them on the previously defined setoninsert part of the update hash.
		# 6.call before persist, this adds the increment aspect to the update hash, and also defines the return_document after parameter.
		# 7.call the collection method find_one_and_update from the ruby driver, and store the result in a variable called persisted doc
		# 8. the doc may be nil if the operation failed, in that case, do nothing.
		# 9. if the persisted doc is not nil, check whether its version is more than the current version and if yes, then set op_success to true.
		# 10. finally call after persist. this basically sets all the attributes from the persisted document onto the present document instance.

		# @note:
		# the op_success is set to false on starting the method , so that in any situation of not being successfull it returns false.
		# the upsert is true, since this is a create call, and if the query conditions yield nothing, the document WILL BE CREATED BY DEFAULT.
		# the query is optional, if not provided, the query is blank, and the present document will be created, since upsert is true.
		# setOnInsert is used, since this is the only way to set the _id while creating a new record. $set does not allow to set the id.
		# document keys "version" and "op_success" are not set in setoninsert, because 
		# a) version is incremented in the $inc part of the update - specified in before update
		# b) op_success is not to be persisted, because we dont want older persistence success/failures to interfere with present ones. So that field is never persisted.
		# remember that the as_document hash is frozen, so suppose you assign it to another variable and delete some key from that variable, it also gets deleted from as_document and all variables that are connected to it, it is for this reason, that while setting the  "setoninsert" we ignore the keys if they are version or op_success instead of deleting afterwards from the hash.## had a lot of trouble with this ##
		def versioned_create(query={},log=false)
		 		

		 		self.send("op_success=",false) 		
		 		update = {}
		 		options = {}
		 		id_query = {"_id" => as_document["_id"]}
		 	
		 		query = query.empty? ? id_query : query


				if version == 0

					update["$setOnInsert"] = {}
		 			options[:upsert] = true
					
		 			expected_version = 1

					prepare_insert(options) do
						
						as_document.keys.each do |k|
			 				if (k != "version" && k != "op_success")
			 					update["$setOnInsert"][k] = as_document[k]
			 				end
			 			end

			 			update["$setOnInsert"]["version"] = 1

						options,update = self.class.before_persist(options,update,true)

							self.class.log_opts(query,update,options,"create",log)
						
							persisted_doc = collection.find_one_and_update(query,update,options)
		
							if persisted_doc.nil?
								self.send("op_success=",false)
							else
								if persisted_doc["version"] == expected_version
									self.send("op_success=",true)
								end	
							
								self.class.after_persist(persisted_doc,self)
							end	
						
					end

					
				end	        

				return query,update,options  
						
		end

		#@param dirty_fields[Hash] - a hash where the keys should be the name of the fields that need to be updated, values should be nil, they are assigned by the method.
		#@return [Boolean] always returns true.
		#@logic ;
		#
		# 1. assigns op_success to false at the beginning, so that it will be true only if the method passess successfully.
		# 2. curr_doc - a variable to hold the result of the as_document function. this helps so that as_document doesn't need to be called again and again.
		# 3. if the dirty fields are empty, we equate it to curr_doc. i.e all the fields of the document are taken up for updating.
		# 4. if the dirty fields are not empty, each dirty field is assigned its value from the curr_doc.
		# 5. check that the curr_doc version si greater than zero. - this is essential to ensure that we only update an existing document.
		# 6. build the query - two thigns are essential here - basically it is an "and" query using _id and version both.
		# 7. set upsert to false - if a document with this version and query is not found, then no persistence is done.
		# 8. now inside the prepare_update block, provided that the field is not "_id" or "version" or "op_success" we add it to the "$set" hash of the update hash. this is because we don't want to set version because it is included in the "$inc" part of the update, and we don't want to set op_success, because this is never persisted, it is just available within the scope of the individual method call(i.e set to false before the method executes and then to to true if successfull or remains false.)
		# 9.call #before_persist so that the "$inc" part is set on the update and return_document is set to after
		# 10. call the collection method find_one_and_update with the query,update and options.
		# 11. store the results in variable persisted_doc, and provided that its not nil,
		#a. set the op_success to true.
		#b. assign all the fields from the persisted doc to the present instance (self) in the after persist method.
		def versioned_update(dirty_fields={},bypass_versioning=false,optional_update_hash={},log=false)
				
			self.send("op_success=",false)
			query = {}
			options = {}
			update = {}
			curr_doc = as_document
			
			##if the dirty fields are empty, the become equal to the document represented as a hash.
			##else, we just equate their values to the fields that have changed.
			if dirty_fields.empty?
				dirty_fields = curr_doc
			else
				dirty_fields.keys.each do |d|
					dirty_fields[d] = curr_doc[d]
				end
			end


			if curr_doc["version"] > 0
				
				if !bypass_versioning
					query["version"] = curr_doc["version"]
				end
				query["_id"] = curr_doc["_id"]
				update["$set"] = {}	
				options[:upsert] = false
				expected_version = curr_doc["version"] + 1

				prepare_update(options) do

					dirty_fields.keys.each do |k|
						if (k != "version" && k != "_id" && k != "op_success")
							update["$set"][k] = dirty_fields[k]
						end
					end

					
						
					update = optional_update_hash.empty? ? update : optional_update_hash

					options,update = self.class.before_persist(options,update,bypass_versioning)

					self.class.log_opts(query,update,options,"update",log)

					persisted_doc = collection.find_one_and_update(query,update,options)

					if (persisted_doc.nil?)
						self.send("op_success=",false)
					else
						if persisted_doc["version"] == expected_version
							self.send("op_success=",true)
						end
						
						self.class.after_persist(persisted_doc,self)
												
					end

				end
				
			end

			return query,update,options  

		end

	end
end