module MongoidVersionedAtomic
	
	class DbUnchanged < StandardError
	end

	module VAtomic

		extend ActiveSupport::Concern
	 	
	    included do
	    	field :version, type: Integer, default: 0
	    	field :op_success, type: Boolean
	    	attr_accessor :matched_count
	    	attr_accessor :modified_count
	    	attr_accessor :upserted_id
	    	#before_save :filter_fields
	    	after_create :check_upserted_id
	    	after_update :check_modified_count


	    end

	    def self.included(base)
	        base.extend(ClassMethods)
	    end

	    module ClassMethods

	    	##@param bson_doc[BSON Document] : a bson_document instance
	    	##@param klass[klass] : klass of the target document.
	    	##converts a bson_doc to the target klass instance.
	    	##return [Object] : either the document in the target class or nil.
	    	def bson_to_mongoid(bson_doc,klass)
			 	if !bson_doc.nil?
			 		
			 		t = Mongoid::Factory.from_db(klass,bson_doc)
			 		return t

			 	else

			 		return nil

			 	end

		 	end

	    	##@param query[Hash] -> query hash, defaults to empty hash.
	    	
	    	##@param update[Hash] -> update hash.
	    	
	    	##@param upsert[Boolean] -> defaults to true
	    	
	    	##@param log[Boolean] -> defaults to false, if set to true, will print the entire query to the console, before executing it.

	    	##@param bypass_versioning[Boolean] -> defaults to false, if true, then versioning will be bypassed.

	    	##@param klass : the class of the document to be modified.

	    	##@logic : 
	    	##will only AFFECT ONE DOCUMENT.
	    	##if the query is empty, then versioning is bypassed, because otherwise, this will lead to an increment of all the documents in the collection.
	    	##basically will find the document specified in the query and if it is not found, then will create a new document with the provided options.
	    	##if it is found, then applies the update hash to found document.
	    	##the version increment is applied to any document that is found, and updated.

	    	##@return mongoid document instance or nil(if the update hash was empty). You need to check the document to see whether it has the changes you requested.
	    	def versioned_upsert_one(query={},update={},klass=nil,upsert=true,log=false,bypass_versioning=false)
	    		
	    		options = {}

	    		if query.empty?
	    			bypass_versioning = true
	    		end

	    		options,update = before_persist(options,update,bypass_versioning)
	    		
				options[:upsert] = upsert
				if !update.empty?
					return bson_to_mongoid(collection.find_one_and_update(query,update,options),klass)
				end

				return nil

	    	end

	    	## @param options[Hash] : this is passed in from the calling method. Before_persist simply adds the return_document[:after] to it, so that the operation returns the changed document.

	    	## @param update[Hash] : this is the update hash that is going to be sent to mongodb, it is also passed in from the calling method.

	    	## If bypass versioning is false(default), then the update inc is set. If there is no "$inc" already in the update hash then we create a new entry for it, otherwise we simply set "version" to be incremented by one.

	    	## @return [Array] : returns the options, and update.
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

	    	##@param doc[Mongodb document] : this is the 'new' document that is got after applying operations on an instance.

	    	##@param instance[Mongodb document] : this is the old document, i.e the instance on which the operation was applied.

	    	##checks each field on the new document
	    	##if it is version, then sets that on the instance.
	    	##if it is any other field, then sets it on the instance if the field is not the same.

	    	##return [Boolean] : always returns true.
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
	    #return attributes[Hash] : the document as a set of key-value fields.
	    def filter_fields
	    
	    	remove_attribute(:version)
	    	remove_attribute(:op_success)
	    	attributes

	    	
	    end

	    ## after create callback , ensures that callback chain is halted if nothing was created.
	    def check_upserted_id
	    	raise DbUnchanged if !self.upserted_id
	    end

	    ## after update callback ensures that callback chain is halted if nothing was modified.
	    def check_modified_count
	    	raise DbUnchanged if !self.modified_count == 1
	    end

		## @param query[Hash] : optional query hash.
		## @param log[Boolean] : defaults to false, set true if you want to print out the final command sent to mongo.

		## @logic:

		## begin the method by setting op_success to false, so that it can be true only if everything works out perfectly.

		## the query defaults to the id of the present instance, or the optional query hash if one is provided.

		## checks that the current version is 0 , otherwise does nothing, this ensures that we only persist new documents.

		## update only sets via "setonInsert". By default, the document is persisted only if 
		## a. its id does not exist in the collection
		## OR
		## b. the parameters supplied in the optional query hash do not find a document in the collection. 

		## 'version' and 'op_success' are not added to the setOnInsert. Version is set in the #before_persist method, and op_success is set after the call to mongo.

		## expected_version is the version we expect to see in the new doucment after applying the operation, provided that the operation actually persists a document.

		## op_success becomes true only if a document is returned after the operation is executed and the version is 1.

		## after_persist sets the fields in the persisted document on the instance.
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

			 			begin
							prepare_insert(options) do
								
								as_document.keys.each do |k|
					 				if (k != "version" && k != "op_success")
					 					update["$setOnInsert"][k] = self.send(k.to_sym)
					 				end
					 			end

					 			update["$setOnInsert"]["version"] = 1

								options,update = self.class.before_persist(options,update,true)

								self.class.log_opts(query,update,options,"create",log)
								
								write_result = collection.update_one(query,update,options)


									
								self.matched_count = write_result.matched_count
								self.modified_count = write_result.modified_count
								self.upserted_id = write_result.upserted_id
								##as long as it matched a document, or it inserted a document
								if write_result.matched_count > 0 || write_result.upserted_id
										self.send("op_success=",true)
										self.version = 1
								else
										self.send("op_success",false)
								end
								
									
										
							end
						rescue DbUnchanged => error
							puts "caught db unchanged error, so callbacks will be halted.-------------------------------------------------------------"
						end 
					
				end	        

				

				return query,update,options  
						
		end

		## @param dirty_fields[Hash] : an optional hash, whose keys should be the names of the fields that have changed i.e should be updated, defaults to empty, which results in all the fields of the document being updated.

		## @param bypass_versioning[Boolean] : whether the version check should be bypassed. Defaults to false. Default condition is that the updated query should have both, the document id + the document version. And the update hash should increment the document version. If the bypass_versioning flag is set to true, then document_version is not considered in the query and it is not incremented in the update hash.

		## @param optional_update_hash[Hash] : an optional hash, that defaults to being empty. If provided it is used as the update hash in the final command sent to mongo. If not provided, it remains empty, and all those fields which are considered dirty are assigned to the "$set" in the update hash. The "$inc" part for versioning is not affected whether this hash is provided or not, since it is set in the before_persist. 

		##@param log[Boolean] : defaults to false, if set to true will print out the final command sent to mongo.

		##@logic:

		##set op_success to false at the beginning.

		##if dirty fields is empty, then it becomes the document as a hash of key_values.

		##if it has something in it, then set the values of the dirty fields keys to whatever is the value of the respective field in the document.

		##proceed only if the doc_version is greater than 0

		##all fields to be persisted are put into the "$set" part of the update, and upsert is set to false.

		##after the call to mongo, provided that the persisted_document is not nil, two possibilities.

		##if bypass versioning is true, then op is successfull since we dont look at versions.

		##if false, then op is successfull only if version == expected version.

		##finally call after_persist to set all the changed fields on the document.
		##this becomes relevant especially in case where you pass in an optional update hash with an "$inc" for some field. The incremented value is not there on the instance, since the instance has the older value and this must be set if the op is successfull on the instance.
		def versioned_update(dirty_fields={},bypass_versioning=false,optional_update_hash={},log=false)
			self.send("op_success=",false)
			query = {}
			options = {}
			update = {}
			curr_doc = as_document
			
			

			##if the dirty fields are empty then it becomes equal to a hash whose keys are the document attributes, and whose values for each key are nil, 
			##otherwise dirty_fields stays as it is.
			dirty_fields = dirty_fields.empty? ? Hash[curr_doc.keys.zip([])] : dirty_fields
			
			if curr_doc["version"] > 0
				
				if !bypass_versioning
					query["version"] = curr_doc["version"]
				end
				query["_id"] = curr_doc["_id"]
				update["$set"] = {}	
				options[:upsert] = false
				expected_version = curr_doc["version"] + 1

				##what happens is that we send the update["$set"][k] to whatever was stored in the dirty_fields.
				begin
				prepare_update(options) do
					
					dirty_fields.keys.each do |k|
						if (k != "version" && k != "_id" && k != "op_success")
							update["$set"][k] = self.send(k.to_sym)
						end
					end


					update = optional_update_hash.empty? ? update : optional_update_hash

					options,update = self.class.before_persist(options,update,bypass_versioning)

					self.class.log_opts(query,update,options,"update",log)

					write_result = collection.update_one(query,update,options)
					
					if write_result.modified_count == 1
						self.send("op_success=",true)
						persisted_doc = self.class.to_s.constantize.find(self.to_param)
						persisted_doc = persisted_doc.attributes
						self.class.after_persist(persisted_doc,self)
					else
						self.send("op_success=",false)
					end

				end
				rescue DbUnchanged => error
					#puts "Rescued db unchanged error, so remaining after update callbacks will be halted."
				end 
				
			end

			return query,update,options  

		end

	end
end