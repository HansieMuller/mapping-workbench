module Importer
  class Upload
    def self.call(user, race, file)
      raise WorkbookGuard::Error, "Choose an XLSX workbook" unless file.is_a?(ActionDispatch::Http::UploadedFile)
      raise WorkbookGuard::Error, "Only .xlsx uploads are supported" unless file.original_filename.downcase.end_with?(".xlsx")
      WorkbookGuard.validate!(file.path)
      batch = user.import_batches.build(event: race.event, race: race, file_name: File.basename(file.original_filename))
      batch.source_file.attach(io: file.tempfile, filename: batch.file_name,
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", identify: false)
      batch.save!
      preview = WorkbookPreview.call(batch)
      batch.update!(preview_data: preview, mapping_config: MappingValidator.suggest(preview))
      batch
    rescue StandardError
      # Cleanup only this new upload, then propagate the error to the appropriate handler.
      if batch&.persisted?
        batch.source_file.purge
        batch.destroy!
      end
      raise
    end
  end
end
