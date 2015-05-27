require 'spec_helper'

describe ActiveTableSet::TableSet do
  let(:leader)         { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1)      { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2)      { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg)  { { :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg)  { { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

  let(:beta_leader)    { { :host => "10.0.0.1",   :username => "beta",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:beta_follower1) { { :host => "10.0.0.2",   :username => "beta1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:beta_follower2) { { :host => "10.0.0.3",   :username => "beta2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:beta_partition_cfg) { { :leader => beta_leader, :followers => [beta_follower1, beta_follower2] } }

  let(:multi_table_set_cfg)  { { :name => "test_multi", :partitions => [partition_cfg, beta_partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

  let(:config)        { ActiveTableSet::TableSet.new(table_set_cfg) }

  context "config" do

    it "provides an array of Partition Configs" do
      expect(config.partitions.count).to eq(1)
    end

    it "support a dsl for defining the table set" do
      table_set = ActiveTableSet::TableSet.config do |ts|
        ts.access_policy do |ap|
          ap.disallow_read = "cf_%"
        end

        ts.partition do |partition|
          partition.leader = leader
          partition.followers = [follower1, follower2]
        end
      end

      expect(table_set.access_policy.disallow_read).to eq("cf_%")
      expect(table_set.partitions.length).to eq(1)
      expect(table_set.partitions.first.leader.host).to eq("127.0.0.8")
    end
  end

  context "construction" do
    it "raises if not passed partitions" do
      expect { ActiveTableSet::TableSet.new }.to raise_error(ArgumentError, "must provide one or more partitions")
    end
  end

  context "connections" do
    it "selects correct partition to grab a connection key from" do
      table_set = ActiveTableSet::TableSet.new(table_set_cfg)
      table_set.connection_key(access_mode: :write, partition_id: 0)
    end
  end

  context "access_policy" do
    it "keeps an access policy" do
      table_set = ActiveTableSet::TableSet.new(table_set_cfg)
      expect(table_set.access_policy.disallow_read).to eq("cf_%")
    end
  end

  context "partition selection" do
    it "can construct a table set with multiple partitions" do
      config = ActiveTableSet::TableSet.new(multi_table_set_cfg)
      expect(config.partitions.count).to eq(2)
      expect(config.partitions.map(&:partition_key).sort).to eq([])
    end

    it "raises an exception if we have more than one partition and any partitions do not have a key" do
      cfg = {
          partitions: [
              { :leader => leader, :followers => [follower1, follower2] },
              beta_partition_cfg
          ]
      }

      expect { ActiveTableSet::TableSet.new(cfg) }.to raise_error(ArgumentError, "all partitions must have keys if more than one partition")

    end

  end
end
