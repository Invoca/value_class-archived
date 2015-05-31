require 'spec_helper'

describe ActiveTableSet::Extensions::ConnectionOverride do
  context "AREL injection" do

    class TestDummy < ActiveRecord::Base
    end

    it "overloads ActiveRecord::Base.connection to return a ConnectionProxy" do
      ActiveTableSet.config do |conf|
        conf.enforce_access_policy true
        conf.environment           'test'
        conf.default_connection  =  { table_set: :common }

        conf.table_set do |ts|
          ts.name = :common

          ts.access_policy do |ap|
            ap.disallow_read  'cf_%'
            ap.disallow_write 'cf_%'
          end

          ts.partition do |part|
            part.leader do |leader|
              leader.host      "10.0.0.1"
              leader.read_write_username  "tester"
              leader.read_write_password  "verysecure"
              leader.database  "main"
            end
          end
        end
      end

      ActiveTableSet.enable
      connection = TestDummy.connection
      expect(connection.is_a?(ActiveTableSet::ConnectionProxy)).to eq(true)
    end
  end
end
