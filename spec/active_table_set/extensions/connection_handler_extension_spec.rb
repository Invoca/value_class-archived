require 'spec_helper'

describe ActiveTableSet::Extensions::ConnectionHandlerExtension do

  def map_hash_to_spec(hash)

    spec_class.new(con_spec.to_hash, con_spec.connector_name)
  end

  let(:connection_handler) {StubConnectionHandler.new}

  let(:spec_class) {
    if defined?(ActiveRecord::ConnectionAdapters::ConnectionSpecification)
      ActiveRecord::ConnectionAdapters::ConnectionSpecification
    else
      ActiveRecord::Base::ConnectionSpecification
    end
  }

  let(:default_spec) do
    spec_class.new(
      ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some.ip",
        read_write_username: "test_user",
        read_write_password: "secure_pwd",
        database: "my_database").to_hash,
      'stub_client_connection' )
  end

  let(:alternate_spec) do
    spec_class.new(
      ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some_other.ip",
        read_write_username: "test_user2",
        read_write_password: "secure_pwd2",
        database: "my_database2").to_hash,
      'some_method' )
  end

  context "connection handler extension" do

    it "has thread variables" do
      connection_handler.thread_connection_spec = :value
      expect(connection_handler.thread_connection_spec).to eq(:value)
    end

    it "returns the default connection if the thread is not overloaded" do
      connection_handler.default_spec(default_spec)
      expect(connection_handler.current_config).to eq(default_spec.config)
    end

    it "returns the thread connection spec when set" do
      connection_handler.default_spec(default_spec)
      connection_handler.current_spec = alternate_spec
      expect(connection_handler.current_config).to eq(alternate_spec.config)
    end

    it "adds the access policy to the connection if connection monitoring is required" do
      expect(ActiveTableSet).to receive(:enforce_access_policy?) { true }
      connection_handler.default_spec(default_spec)
      connection = connection_handler.connection
      expect(connection.respond_to?(:show_error_in_bars)).to eq(true)
    end

    it "does not add the access policy to the connection if connection monitoring is not required" do
      expect(ActiveTableSet).to receive(:enforce_access_policy?) { false }
      connection_handler.default_spec(default_spec)
      connection = connection_handler.connection
      expect(connection.respond_to?(:show_error_in_bars)).to eq(false)
    end

    it "adds the using method to the connection class" do
      expect(ActiveTableSet).to receive(:enforce_access_policy?) { false }
      connection_handler.default_spec(default_spec)
      connection = connection_handler.connection

      expect(connection.respond_to?(:using)).to eq(true)

      @called_block = false
      expect(ActiveTableSet).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
      connection.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end

    it "has a pool for spec method" do
      connection_handler.default_spec(default_spec)
      expect(connection_handler.pool_for_spec(default_spec).spec.config).to eq(default_spec.config)
    end

    context "pool leaking" do
      it "does not leak pools if a connection handler mutates the connection" do
        allow(ActiveTableSet).to receive(:enforce_access_policy?) { true }

        connection_handler.default_spec(default_spec)

        # Some connection classes mutate the config.  Simulate that here.
        connection1 = connection_handler.connection
        connection1.config["flags"] = 2

        expect(connection_handler.connection_pools.count).to eq(1)

        # Need a new spec because it was mutated above...
        default_spec_2 = spec_class.new(
          ActiveTableSet::Configuration::DatabaseConnection.new(
            host: "some.ip",
            read_write_username: "test_user",
            read_write_password: "secure_pwd",
            database: "my_database").to_hash,
          'some_method' )

        connection_handler.current_spec = default_spec_2

        connection2 = connection_handler.connection
        expect(connection_handler.connection_pools.count).to eq(1)
      end

      it "returns the same connection when accessing the same pool" do
        allow(ActiveTableSet).to receive(:enforce_access_policy?) { false }

        connection_handler.default_spec(default_spec)
        connection1 = connection_handler.connection

        connection_handler.current_spec = default_spec
        connection2 = connection_handler.connection

        expect(connection1.object_id).to eq(connection2.object_id)
      end
    end
  end
end