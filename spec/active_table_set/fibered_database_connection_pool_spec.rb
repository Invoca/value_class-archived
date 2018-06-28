require 'spec_helper'
require 'active_table_set/fibered_database_connection_pool'
require 'rspec/mocks'
require 'active_record/connection_adapters/em_mysql2_adapter'

class TestMonitor
  include ActiveTableSet::FiberedMonitorMixin

  attr_reader :mon_count, :condition

  def initialize
    mon_initialize

    @condition = new_cond
  end
end

describe ActiveTableSet::FiberedDatabaseConnectionPool do
  before do
    @exceptions = []
    @next_ticks = []
    @trace      = []
    allow(ExceptionHandling).to receive(:log_error) { |*args| store_exception(args) }
    allow(EM).to receive(:next_tick) { |&block| queue_next_tick(&block) }
  end

  after do
    expect(@exceptions).to eq([])
  end

  describe ActiveTableSet::FiberedMonitorMixin do
    before do
      @monitor    = TestMonitor.new
    end

    it "should implement mutual exclusion" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK"
            trace "fiber #{i} yield"
            Fiber.yield
            trace "fiber #{i} UNLOCK"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 1
      resume 0
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK",
                             "fiber 0 yield",
                             "fiber 1 RESUME",
                             "fiber 1 begin",    # fiber 1 yields because it can't lock mutex
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK",
                             "next_tick queued",
                             # 1 yields back to 0
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK",
                             "fiber 1 yield",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK",
                             "fiber 1 end"
                           ])
    end

    it "should keep a ref count on the mutex (yield after 1st lock)" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            trace "fiber #{i} yield A"
            Fiber.yield
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield B"
              Fiber.yield
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 1
      resume 0
      resume 0
      resume 1
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                  # fiber 1 yields because it can't get the lock
                             "fiber 0 RESUME",
                             "fiber 0 LOCK 2",
                             "fiber 0 yield B",
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "fiber 1 end"
                           ])
    end

    it "should keep a ref count on the mutex (yield after 2nd lock)" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            trace "fiber #{i} yield A"
            Fiber.yield
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield B"
              Fiber.yield
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 0
      resume 1
      resume 0
      resume 1
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 yield A",
                             "fiber 0 RESUME",
                             "fiber 0 LOCK 2",
                             "fiber 0 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                 # fiber 1 yields because it can't get the lock
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "fiber 1 end"
                           ])
    end

    it "should implement wait/signal on the condition with priority over other mutex waiters" do
      @fibers = (0...3).map do
        Fiber.new do |i, condition_handling|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield"
              Fiber.yield
              case condition_handling
              when :wait
                trace "fiber #{i} WAIT"
                @monitor.condition.wait
                trace "fiber #{i} UNWAIT"
              when :signal
                trace "fiber #{i} SIGNAL"
                @monitor.condition.signal
                trace "fiber #{i} UNSIGNAL"
              end
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0, :wait
      resume 1, :signal
      resume 2, nil
      resume 0
      resume 1
      resume 2

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 LOCK 2",    # fiber 0 locks the mutex
                             "fiber 0 yield",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                  # fiber 1 yields because it can't lock the mutex
                             "fiber 2 RESUME",
                             "fiber 2 begin",
                                                  # fiber 2 yields because it can't lock the mutex
                             "fiber 0 RESUME",
                             "fiber 0 WAIT",
                             "next_tick queued",
                                                  # fiber 0 yields while waiting for condition to be signaled
                             "next_tick.call",    # fiber 0 yields mutex to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield",
                             "fiber 1 RESUME",
                             "fiber 1 SIGNAL",
                             "next_tick queued",
                             "fiber 1 UNSIGNAL",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "next_tick queued",
                             "fiber 1 end",
                             "next_tick.call",
                             "next_tick.call",    # fiber 1 yields to fiber 0 that was waiting for the signal (this takes priority over fiber 2 that was already waiting on the mutex)
                             "fiber 0 UNWAIT",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",
                             "fiber 2 LOCK 1",
                             "fiber 2 LOCK 2",
                             "fiber 2 yield",
                             "fiber 2 RESUME",
                             "fiber 2 UNLOCK 2",
                             "fiber 2 UNLOCK 1",
                             "fiber 2 end"
                           ])
    end
  end

  describe ActiveRecord::ConnectionAdapters::ConnectionPool::Queue do
    before do
      @timers     = []
      allow(EM).to receive(:add_timer) { |&block| queue_timer(&block); block }
      allow(EM).to receive(:cancel_timer) { |block| cancel_timer(block) }
    end

    describe "poll" do
      it "should return added entries immediately" do
        spec = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new({ database: 'rr_prod', host: 'master.ringrevenue.net' }, :em_mysql2)
        cp = ActiveTableSet::FiberedDatabaseConnectionPool.new(spec)
        queue = cp.instance_variable_get(:@available)
        queue.add(1)
        polled = []
        fiber = Fiber.new { polled << queue.poll(1) }
        fiber.resume
        expect(polled).to eq([1])
      end

      it "should block when queue is empty" do
        spec = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new({ database: 'rr_prod', host: 'master.ringrevenue.net' }, :em_mysql2)
        cp = ActiveTableSet::FiberedDatabaseConnectionPool.new(spec)
        queue = cp.instance_variable_get(:@available)
        polled = []
        fiber = Fiber.new { polled << queue.poll(10) }
        fiber.resume
        queue.add(1)
        run_next_ticks
        expect(polled).to eq([1])
      end
    end
  end

  describe ActiveRecord::ConnectionAdapters::ConnectionPool do
    it "should serve separate connections per fiber" do
      configure_ats_like_ringswitch
      ActiveTableSet.enable

      connection_stub = Object.new
      allow(connection_stub).to receive(:query_options) { {} }
      expect(connection_stub).to receive(:query) do |*args|
        expect(args).to eq(["SET SQL_AUTO_IS_NULL=0, NAMES 'utf8', @@wait_timeout = 2147483"])
      end.exactly(2).times
      allow(connection_stub).to receive(:ping) { true }
      allow(connection_stub).to receive(:close)

      allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

      c1 = ActiveRecord::Base.connection
      c2 = nil
      fiber = Fiber.new { c2 = ActiveRecord::Base.connection }
      fiber.resume

      expect(c1).to be
      expect(c2).to be
      expect(c2).to_not eq(c1)
      expect(c2.fiber_owner).to eq(fiber)
      expect(c1.in_use?).to be
      expect(c2.in_use?).to be
    end
  end

private
  def trace(message)
    @trace << message
  end

  def queue_next_tick(&block)
    block or raise "Nil block passed!"
    trace "next_tick queued"
    @next_ticks << block
  end

  def run_next_ticks
    while (next_tick_block = @next_ticks.shift)
      @trace << "next_tick.call"
      next_tick_block.call
    end
  end

  def resume(fiber, *args)
    trace "fiber #{fiber} RESUME"
    @fibers[fiber].resume(fiber, *args)
    run_next_ticks
  end

  def queue_timer(&block)
    @timers << block
  end

  def cancel_timer(timer_block)
    @timers.delete_if { |block| block == timer_block }
  end

  def store_exception(args)
    @exceptions << args
  end

  def configure_ats_like_ringswitch
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :ringswitch }

      conf.table_set do |ts|
        ts.name = :ringswitch
        ts.adapter = 'fibered_mysql2'
        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end
        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end

      conf.table_set do |ts|
        ts.name = :ringswitch_jobs
        ts.adapter = 'fibered_mysql2'
        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end
  end
end