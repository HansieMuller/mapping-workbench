require "test_helper"
require "timeout"

class Importer::PostgresqlConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { create_context }
  teardown do
    [ ImportRow, RaceResult, Membership, ImportBatch, Athlete, Club, Race, Event, Session, User,
      PaperTrail::Version, ActiveStorage::Attachment, ActiveStorage::Blob ].each(&:delete_all)
  end

  test "competing sessions cannot overlap job ownership or resume an active worker" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    batch.update!(status: :queued, total_rows: 8)
    ready, release = Queue.new, Queue.new
    owner = Thread.new do
      Importer::DatabaseLock.with_batch(batch.id) do
        ready << ActiveRecord::Base.connection.raw_connection.backend_pid
        Timeout.timeout(10) { release.pop }
      end
    end
    owner_pid = Timeout.timeout(10) { ready.pop }
    assert_not_equal owner_pid, ActiveRecord::Base.connection.raw_connection.backend_pid
    assert_equal false, Importer::WorkbookImporter.new(batch).call
    assert_raises(Importer::MappingValidator::Error) { batch.resume! }
    assert_equal "queued", batch.reload.status
    assert_equal 0, batch.attempts
    release << true
    owner.value
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal "completed", batch.reload.status
  ensure
    release << true if release
    owner&.join(10)
  end

  test "real uniqueness collision rolls back savepoint and the full row retries successfully" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    batch.update!(status: :queued, total_rows: 8)
    athlete = Athlete.create!(full_name: "Luma Quill", id_number: "0000000000001", date_of_birth: Date.new(1991, 4, 12))
    ready, release = Queue.new, Queue.new
    savepoint_rollback = false
    callback = proc do |result|
      if Thread.current[:workbench_collision] && result.race_number == "101"
        Thread.current[:workbench_collision] = false
        ready << ActiveRecord::Base.connection.raw_connection.backend_pid
        Timeout.timeout(10) { release.pop }
      end
    end
    listener = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      savepoint_rollback = true if args.last[:sql].include?("ROLLBACK TO SAVEPOINT")
    end
    RaceResult.set_callback(:create, :before, callback)
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Thread.current[:workbench_collision] = true
        # Force nesting to prove actual savepoint recovery as well as normal row transactions.
        ActiveRecord::Base.transaction { Importer::WorkbookImporter.new(ImportBatch.find(batch.id)).call }
      end
    end
    worker_pid = Timeout.timeout(10) { ready.pop }
    assert_not_equal worker_pid, ActiveRecord::Base.connection.raw_connection.backend_pid
    winner = RaceResult.create!(race: @race, athlete: athlete, import_batch: batch, race_number: "101", finish_time_seconds: 1)
    release << true
    worker.value
    assert savepoint_rollback, "Expected PostgreSQL to roll back the failed insert savepoint"
    assert_equal "completed", batch.reload.status
    assert_equal 1, RaceResult.where(race: @race, race_number: "101").count
    assert_equal winner.id, batch.import_rows.find_by(source_sheet: "Results", source_row_number: 4).race_result_id
    assert_equal 3083, winner.reload.finish_time_seconds
    assert_equal 6, Athlete.count
  ensure
    release << true if release
    worker&.join(10)
    RaceResult.skip_callback(:create, :before, callback) if callback
    ActiveSupport::Notifications.unsubscribe(listener) if listener
  end

  test "concurrent identities and clubs resolve to one relational graph" do
    batch = create_batch
    start = Queue.new
    workers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Timeout.timeout(10) { start.pop }
          Athlete.transaction do
            Importer::AthleteResolver.new(batch, "full_name" => "Iris Fable", "id_number" => "0000000000021", "club" => "Moonfern Striders").resolve.id
          end
        end
      end
    end
    2.times { start << true }
    assert_equal 1, workers.map(&:value).uniq.size
    assert_equal 1, Athlete.count
    assert_equal 1, Club.count
    assert_equal 1, Membership.count
  end
  test "terminated backend cannot resume writing after a replacement worker completes" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    batch.update!(status: :queued, total_rows: 8)
    ready, release = Queue.new, Queue.new
    stale = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        importer = Importer::WorkbookImporter.new(ImportBatch.find(batch.id))
        first = true
        importer.define_singleton_method(:process_row) do |*args|
          super(*args)
          if first
            first = false
            ready << ActiveRecord::Base.connection.exec_query("SELECT pg_backend_pid()").rows.first.first
            Timeout.timeout(10) { release.pop }
          end
        end
        begin
          importer.call
        rescue Importer::DatabaseLock::OwnershipLost
          :ownership_lost
        end
      end
    end
    pid = Timeout.timeout(10) { ready.pop }
    bind = ActiveRecord::Relation::QueryAttribute.new("pid", pid, ActiveRecord::Type::Integer.new)
    terminated = ActiveRecord::Base.connection.exec_query("SELECT pg_terminate_backend($1)", "Terminate only test worker", [ bind ]).rows.first.first
    assert terminated
    assert_equal 1, batch.reload.import_rows.where(status: "imported").count
    batch.resume!
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal "completed", batch.reload.status
    replacement_state = batch.attributes
    version_count = PaperTrail::Version.count
    release << true
    assert_equal :ownership_lost, stale.value
    assert_equal replacement_state, batch.reload.attributes
    assert_equal version_count, PaperTrail::Version.count
    assert_equal 6, batch.imported_rows
    assert_equal 4, RaceResult.count
  ensure
    release << true if release
    stale&.join(10)
  end
end
