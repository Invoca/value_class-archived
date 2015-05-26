#
# Partition represents a set of one leader and zero or more followers.
#

module ActiveTableSet
  class Partition
    include ValueClass::Constructable

    # TODO Need partition key, and need interface to use it.
    #value_attr      :partition_key
    value_attr      :leader,    class_name: 'ActiveTableSet::DatabaseConfig'
    value_list_attr :followers, class_name: 'ActiveTableSet::DatabaseConfig', insert_method: 'follower'

    attr_reader :keys
    attr_reader :index

    def initialize(options={})
      super
      leader or raise ArgumentError, "must provide a leader"

      @keys = [leader] + followers
      @index = 0
    end

    def leader_key
      leader
    end

    def follower_keys
      followers
    end


    # # must have 1 leader and can have 0..x followers
    # def initialize(leader_key:, follower_keys: [], index: 0)
    #   @keys  = [leader_key].concat(follower_keys)
    #   @index = index
    # end

    def connection_key(access_mode: :write)
      case access_mode
      when :write, :read
        leader
      when :balanced
        chosen_follower
      else
        raise ArgumentError, "unknown access_mode"
      end
    end

    private


    def chosen_follower
      if has_followers?
        @chosen_follower ||= keys[follower_index+1]
      else
# TODO - Nil doesn't seem right here.
        nil
#        leader.key
      end
    end

    def has_followers?
      followers.count > 1
    end

    ## TODO - I want to keep this as a immutable value object,
    ##   I would prefer that this be passed in.
    def follower_index
      $$ % (keys.count - 1)
    end
  end
end
