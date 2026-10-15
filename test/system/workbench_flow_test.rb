require "application_system_test_case"
require "sidekiq/api"

class WorkbenchFlowTest < ApplicationSystemTestCase
  setup do
    create_context
    assert_instance_of ActionCable::SubscriptionAdapter::Redis, ActionCable.server.pubsub
  end
  teardown do
    warn page.driver.browser.logs.get(:browser).map(&:message).join("\n") unless passed?
    [ ImportRow, RaceResult, Membership, ImportBatch, Athlete, Club, Race, Event, Session, User,
      PaperTrail::Version, ActiveStorage::Attachment, ActiveStorage::Blob ].each(&:delete_all)
  end

  def browser_sign_in
    visit root_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "synthetic-test-password"
    click_button "Sign in"
    assert_text "Workbook import history"
  end

  test "full authenticated workbook wizard uses Redis Sidekiq PostgreSQL and live ActionCable" do
    assert_equal :sidekiq, Rails.application.config.active_job.queue_adapter
    browser_sign_in
    click_link "New import →"
    select @event.display_name, from: "Existing event"
    select "#{@event.name} · #{@race.display_name}", from: "Existing race"
    click_button "Continue to upload"
    assert_text "Upload workbook"
    attach_file "XLSX workbook", Rails.root.join("test/fixtures/files/mixed.xlsx")
    click_button "Preview workbook"
    assert_text "Confirm the header rows"
    assert_selector "[data-cable-connected='true']"
    assert_selector "[data-cable-status='pending_mapping']"
    assert_text "Unnamed column"
    assert_selector "option[value='passport_number']", count: 0
    page.find("section.sheet", match: :first).native.save_screenshot(Rails.root.join("tmp/screenshots/mapping.png"))
    click_button "Confirm mappings and start import"
    assert_text "Persisted row outcomes"
    assert_selector "[data-cable-status='completed_with_errors']", wait: 30
    batch = ImportBatch.last
    assert_equal 6, batch.reload.imported_rows
    assert_equal 3, batch.failed_rows
    assert_equal 4, RaceResult.count
    assert_match(/[a-f0-9]{24}/, batch.job_id)
    assert_equal "User:#{@user.id}", RaceResult.first.versions.last.whodunnit
    assert_selector "[data-cable-connected='true'][data-cable-status='completed_with_errors']"
    assert_text "Time minutes and seconds must be less than 60"
    page.execute_script("window.scrollTo(0,0)")
    page.save_screenshot(Rails.root.join("tmp/screenshots/outcomes.png"))
    click_link "Results", exact: true
    assert_text "Luma Quill"
    page.save_screenshot(Rails.root.join("tmp/screenshots/results.png"))
    page.driver.browser.manage.window.resize_to(390, 844)
    click_link "Import history", exact: true
    assert_text "mixed.xlsx"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Mobile page should contain horizontal overflow within its tables"
    page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-history.png"))
  end

  test "existing page receives queued and completed broadcasts without a manual refresh" do
    browser_sign_in
    batch = attach_workbook(create_batch, name: "success.xlsx")
    visit import_batch_path(batch)
    assert_selector "[data-cable-status='pending_mapping']"
    page.execute_script("window.observedProgress = []; new MutationObserver(() => window.observedProgress.push(document.querySelector('[data-cable-status]')?.dataset.cableStatus)).observe(document.querySelector('[data-cable-status]'), { attributes: true, attributeFilter: ['data-cable-status'] })")
    batch.queue!(batch.mapping_config)
    assert_selector "[data-cable-status='completed']", wait: 30
    assert_selector "[data-import-progress-target='imported']", text: "6"
    assert_equal 2, batch.reload.skipped_rows
    assert_text "Persisted row outcomes"
    states = page.evaluate_script("window.observedProgress")
    assert_includes states, "processing"
    assert_includes states, "completed"
  end
end
