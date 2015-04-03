require 'spec_helper'

describe ActiveTableSet::ConnectionProxy do
  let(:leader)        { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1)     { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2)     { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg) { { :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg) { { :name => "test_ts", :partitions => [partition_cfg], :readable => ["zebras", "rhinos", "lions"], :writeable => ["tourists", "guides"] } }
  let(:main_cfg)      { { :table_sets => [table_set_cfg] } }

  context "construction" do
    it "raises on missing config parameter" do
      expect { ActiveTableSet::ConnectionProxy.new }.to raise_error(ArgumentError, "missing keyword: config")
    end
  end

  context "table set construction" do
    it "constructs a hash of table sets based on configuration hash" do
      proxy = ActiveTableSet::ConnectionProxy.new(config: main_cfg)
      expect(proxy.table_set_names.length).to eq(1)
      expect(proxy.table_set_names[0]).to eq("test_ts")
    end
  end

  context "finds correct keys" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: main_cfg) }

    it "for access_mode :write" do
      key = proxy.connection_key(table_set: "test_ts", access_mode: :write)
      expect(key.host).to eq("127.0.0.8")
    end

    it "for access_mode :read" do
      key = proxy.connection_key(table_set: "test_ts", access_mode: :read)
      expect(key.host).to eq("127.0.0.8")
    end

    it "for access_mode :balanced with chosen_follower of index 0" do
      part = proxy.send(:table_sets)["test_ts"].partitions[0]
      allow(part).to receive(:follower_index).and_return(0)
      key = proxy.connection_key(table_set: "test_ts", access_mode: :balanced)
      expect(key.host).to eq("127.0.0.9")
    end

    it "for access_mode :balanced with chosen_follower of index 1" do
      part = proxy.send(:table_sets)["test_ts"].partitions[0]
      allow(part).to receive(:follower_index).and_return(1)
      key = proxy.connection_key(table_set: "test_ts", access_mode: :balanced)
      expect(key.host).to eq("127.0.0.10")
    end

    it "raises if request table_set does not exist" do
      expect { proxy.connection_key(table_set: "whatever") }.to raise_error(ArgumentError, "pool key requested from unknown table set whatever")
    end
  end

  context "using PoolManager" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: main_cfg) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "gets a new pool from PoolManager" do
      allow(mgr).to receive(:create_pool).and_return("stand-in_for_actual_pool")

      leader_key = proxy.connection_key(table_set: "test_ts", access_mode: :write)
      pool = proxy.pool(key: leader_key)
      expect(mgr.pool_count).to eq(1)
      expect(pool).to eq("stand-in_for_actual_pool")
    end

    it "gets same pool from PoolManager for same pool key" do
      allow(mgr).to receive(:create_pool).once.and_return("stand-in_for_actual_pool")

      leader_key = proxy.connection_key(table_set: "test_ts", access_mode: :write)
      pool = proxy.pool(key: leader_key)
      expect(mgr.pool_count).to eq(1)
      expect(pool).to eq("stand-in_for_actual_pool")

      pool2 = proxy.pool(key: leader_key)
      expect(pool).to eq(pool2)
    end
  end

  context "retrieves connections with default timeout" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: main_cfg) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "for access_mode :write" do
      test_pool = double("write_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :write)
      expect(connection).to eq("stand-in_for_actual_connection")
    end

    it "for access_mode :read" do
      test_pool = double("read_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :write)
      expect(connection).to eq("stand-in_for_actual_connection")
    end

    it "for access_mode :balanced" do
      test_pool = double("balanced_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :write)
      expect(connection).to eq("stand-in_for_actual_connection")
    end
  end

  context "retrieves connections with timeout over-ride" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: main_cfg) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "for access_mode :write" do
      test_pool = double("write_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :write, timeout: 25)
      expect(connection).to eq("stand-in_for_actual_connection")
    end

    it "for access_mode :read" do
      test_pool = double("read_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :read, timeout: 25)
      expect(connection).to eq("stand-in_for_actual_connection")
    end

    it "for access_mode :balanced" do
      test_pool = double("balanced_pool")
      expect(test_pool).to receive(:connection) { "stand-in_for_actual_connection" }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)
      connection = proxy.connection(table_set: "test_ts", access_mode: :balanced, timeout: 25)
      expect(connection).to eq("stand-in_for_actual_connection")
    end
  end
end