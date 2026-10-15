module Importer
  class DatabaseLock
    NAMESPACE = 741_923

    def self.call(connection, sql, key)
      binds = [ NAMESPACE, Integer(key) ].map { |v| ActiveRecord::Relation::QueryAttribute.new("lock", v, ActiveRecord::Type::Integer.new) }
      connection.exec_query(sql, "Workbench lock", binds).rows.first.first
    end

    # Session ownership survives row commits and disappears if the worker connection dies.
    def self.with_batch(id)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        acquired = call(connection, "SELECT pg_try_advisory_lock($1, $2)", id)
        return false unless acquired
        begin
          yield
        ensure
          call(connection, "SELECT pg_advisory_unlock($1, $2)", id)
        end
      end
      true
    end

    def self.lock_identities!
      call(ActiveRecord::Base.connection, "SELECT 1 FROM pg_advisory_xact_lock($1, $2)", 0)
    end
  end
end
