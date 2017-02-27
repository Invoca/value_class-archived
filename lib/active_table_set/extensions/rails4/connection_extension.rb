# Adds convient access to the Acive Table Set methods.
module ActiveTableSet
  module Extensions
    module Rails4
      module ConnectionExtension
        def log(sql, name='', builds=[])
          super(sql, "#{name} host:#{@config[:host]}", builds)
        end

        def using(table_set: nil, access: nil, partition_key: nil, timeout: nil, &blk)
          ActiveTableSet.using(table_set: table_set, access: access, partition_key: partition_key, timeout: timeout, &blk)
        end

        def lock_access(access, &blk)
          ActiveTableSet.lock_access(access, &blk)
        end
      end
    end
  end
end