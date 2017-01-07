class Thing
  include Mongoid::Document
  include MongoidVersionedAtomic::VAtomic
  field :entries, type: Hash, default: {}
end