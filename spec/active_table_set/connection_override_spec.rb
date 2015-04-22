require 'spec_helper'

describe ActiveTableSet::ConnectionOverride do
  context "AREL injection" do

    class TestDummy < ActiveRecord::Base
    end

    it "overloads ActiveRecord::Base.connection to return a ConnectionProxy" do
      connection = TestDummy.connection
      expect(connection.is_a?(ActiveTableSet::ConnectionProxy)).to eq(true)
    end
  end
end
