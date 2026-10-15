module Importer
  class DatabaseLock
    NAMESPACE = 741_923
    class OwnershipLost < StandardError; end

    class Ownership
      def initialize(connection)
        @connection = connection
        @pid = backend_pid
      end

      # ActiveRecord can transparently reconnect. A replacement connection has no advisory lock.
      def verify!
        raise OwnershipLost, "Worker database session changed; stop and resume safely" unless owned?
      end

      def owned?
        backend_pid == @pid
      end

      private

      def backend_pid
        @connection.exec_query("SELECT pg_backend_pid()", "Worker session").rows.first.first
      end
    end

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
          ownership = Ownership.new(connection)
          yield ownership
        ensure
          call(connection, "SELECT pg_advisory_unlock($1, $2)", id) if ownership&.owned?
        end
      end
      true
    end

    def self.lock_identities!
      call(ActiveRecord::Base.connection, "SELECT 1 FROM pg_advisory_xact_lock($1, $2)", 0)
    end
  end
end
