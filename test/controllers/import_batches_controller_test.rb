require "test_helper"

class ImportBatchesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup { create_context; sign_in }

  test "context persists transactionally and enforces event race membership" do
    assert_difference [ "Event.count", "Race.count" ], 1 do
      post context_import_batches_path, params: { import_context: { event_name: "Lantern Festival", event_date: "2026-10-10", race_name: "North Loop", race_distance: "5km" } }
      assert_redirected_to new_import_batch_path(race_id: Race.order(:id).last.id)
    end
    assert_no_difference "Event.count" do
      post context_import_batches_path, params: { import_context: { event_name: "Rollback Festival", event_date: "2026-10-10" } }
      assert_response :unprocessable_entity
    end
    other = Event.create!(name: "Other Fiction", event_date: @event.event_date)
    post context_import_batches_path, params: { import_context: { event_id: other.id, race_id: @race.id } }
    assert_response :unprocessable_entity
    assert_select ".notice", /does not belong/
  end

  test "actual upload preview mapping queue job PostgreSQL outcome and views" do
    post import_batches_path, params: { race_id: @race.id, import_batch: { source_file: fixture_file_upload("mixed.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") } }
    batch = ImportBatch.order(:id).last
    assert_redirected_to import_batch_path(batch)
    get import_batch_path(batch)
    assert_response :success
    assert_select "section.sheet", 3
    assert_select "select", 46
    assert_select ".column-letter", "AB"
    assert_enqueued_with(job: ImportWorkbookJob, args: [ batch.id ]) do
      patch confirm_mapping_import_batch_path(batch), params: { mapping_config: batch.mapping_config }
    end
    assert_equal "queued", batch.reload.status
    ImportWorkbookJob.perform_now(batch.id)
    get import_batch_path(batch)
    assert_select "h2", "Persisted row outcomes"
    assert_select "td", /Luma Quill/
    assert_equal 4, RaceResult.count
    get athletes_path
    assert_response :success
    get race_results_path, params: { q: "Luma" }
    assert_response :success
    assert_select "td", /Luma Quill/
    get import_batches_path, params: { q: "missing-fiction" }
    assert_select "h3", "No matching imports"
  end

  test "upload and all batch endpoints are private to the uploader" do
    batch = attach_workbook(create_batch)
    other = User.create!(email: "other@example.test", password: "synthetic-test-password")
    delete session_path
    sign_in(other)
    get import_batch_path(batch); assert_response :not_found
    get download_import_batch_path(batch); assert_response :not_found
    patch headers_import_batch_path(batch), params: { header_rows: { "0" => "1" } }; assert_response :not_found
    patch confirm_mapping_import_batch_path(batch), params: { mapping_config: batch.mapping_config }; assert_response :not_found
    post resume_import_batch_path(batch); assert_response :not_found
    get "/rails/active_storage/blobs/redirect/fake/file.xlsx"; assert_response :not_found
    delete session_path
    get import_batch_path(batch); assert_redirected_to new_session_path
    get athletes_path; assert_redirected_to new_session_path
    get race_results_path; assert_redirected_to new_session_path
  end

  test "download returns original XLSX with private cache headers" do
    batch = attach_workbook(create_batch)
    get download_import_batch_path(batch)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal File.binread(Rails.root.join("test/fixtures/files/mixed.xlsx")), response.body
  end

  test "crafted mapping fails and queued configuration cannot change" do
    batch = attach_workbook(create_batch)
    config = batch.mapping_config.deep_dup
    config["sheets"]["0"]["9999"] = "race_id"
    patch confirm_mapping_import_batch_path(batch), params: { mapping_config: config }
    assert_redirected_to batch
    assert_equal "pending_mapping", batch.reload.status
    assert_match(/invalid column/, flash[:alert])
    batch.queue!(batch.mapping_config)
    original = batch.mapping_config.deep_dup
    patch confirm_mapping_import_batch_path(batch), params: { mapping_config: config }
    assert_equal "queued", batch.reload.status
    assert_equal original, batch.mapping_config
    patch headers_import_batch_path(batch), params: { header_rows: { "0" => "1" } }
    assert_equal 3, batch.reload.preview_data["sheets"][0]["header_row"]
  end

  test "malformed upload creates no batch and errors are escaped" do
    bad = Rack::Test::UploadedFile.new(StringIO.new("not an xlsx"), "application/octet-stream", original_filename: "malformed.xlsx")
    assert_no_difference "ImportBatch.count" do
      post import_batches_path, params: { race_id: @race.id, import_batch: { source_file: bad } }
    end
    assert_response :unprocessable_entity
    batch = attach_workbook(create_batch)
    batch.update!(status: :failed, fatal_error: '<script>alert("synthetic")</script>')
    get import_batch_path(batch)
    assert_includes response.body, "&lt;script&gt;"
    assert_select "script", { text: /alert\("synthetic"\)/, count: 0 }
  end

  test "CSRF protection rejects a crafted session or mapping POST" do
    ActionController::Base.allow_forgery_protection = true
    post session_path, params: { email: @user.email, password: "synthetic-test-password" }
    assert_response :unprocessable_entity
    batch = attach_workbook(create_batch)
    patch confirm_mapping_import_batch_path(batch), params: { mapping_config: batch.mapping_config }
    assert_response :unprocessable_entity
    assert_equal "pending_mapping", batch.reload.status
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
  test "mapping root strings and arrays are rejected before conversion" do
    batch = attach_workbook(create_batch)
    [ "crafted", [ "crafted" ] ].each do |shape|
      patch confirm_mapping_import_batch_path(batch), params: { mapping_config: shape }
      assert_redirected_to batch
      assert_match(/must be an object/, flash[:alert])
      assert_equal "pending_mapping", batch.reload.status
    end
  end
end
