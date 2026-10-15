class ImportWorkbookJob < ApplicationJob
  queue_as :imports
  sidekiq_options retry: false

  def perform(batch_id)
    batch = ImportBatch.find(batch_id)
    PaperTrail.request(whodunnit: "User:#{batch.user_id}") do
      Importer::WorkbookImporter.new(batch).call
    end
  end
end
