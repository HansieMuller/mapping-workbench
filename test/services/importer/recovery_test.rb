require "test_helper"

class Importer::RecoveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup { create_context }

  test "interrupted import resumes only uncommitted rows and preserves counters and audit" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    batch.update!(status: :queued, total_rows: 8)
    importer = Importer::WorkbookImporter.new(batch)
    count = 0
    importer.define_singleton_method(:process_row) do |*args|
      super(*args)
      count += 1
      raise IOError, "simulated worker interruption" if count == 2
    end
    assert_raises(IOError) { importer.call }
    assert_equal "failed", batch.reload.status
    assert_equal 2, batch.imported_rows
    assert_equal 2, RaceResult.count
    committed_ids = batch.import_rows.pluck(:id)
    first_version_count = RaceResult.first.versions.count
    assert_enqueued_with(job: ImportWorkbookJob, args: [ batch.id ]) { batch.resume! }
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal "completed", batch.reload.status
    assert_equal 6, batch.imported_rows
    assert_equal 2, batch.skipped_rows
    assert_equal 4, RaceResult.count
    assert_equal 2, batch.attempts
    assert_equal committed_ids, batch.import_rows.where(id: committed_ids).pluck(:id)
    assert_equal first_version_count, RaceResult.first.versions.count
  end

  test "queued delivery loss is safe to resume and mappings stay immutable" do
    batch = attach_workbook(create_batch, name: "success.xlsx")
    assert_enqueued_with(job: ImportWorkbookJob) { batch.queue!(batch.mapping_config) }
    assert_raises(Importer::MappingValidator::Error) { batch.queue!(batch.mapping_config) }
    assert_enqueued_with(job: ImportWorkbookJob) { batch.resume! }
    ImportWorkbookJob.perform_now(batch.id)
    assert_equal "completed", batch.reload.status
    assert_raises(Importer::MappingValidator::Error) { batch.resume! }
  end
end
