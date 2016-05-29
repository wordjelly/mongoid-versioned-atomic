require 'test_helper'

class MongoidVersionedAtomicTest < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, MongoidVersionedAtomic
  end
end
