module Importer
  class WorkbookImporter
    ROW_ERRORS = [ InvalidValue, AthleteResolver::IdentityConflict, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique ].freeze

    def initialize(batch)
      @batch = batch
    end

    # Only the connection holding the batch advisory lock may claim/resume this batch.
    # Terminal row checkpoints and domain writes commit together; counters are derived, never reset.
    def call
      DatabaseLock.with_batch(@batch.id) do
        @batch.reload
        next unless @batch.queued?
        MappingValidator.validate!(@batch.preview_data, @batch.mapping_config)
        @batch.update!(status: :processing, claim_token: SecureRandom.uuid,
          attempts: @batch.attempts + 1, started_at: @batch.started_at || Time.current,
          heartbeat_at: Time.current, completed_at: nil, fatal_error: nil)
        @batch.broadcast_progress!
        WorkbookPreview.open(@batch) do |workbook|
          @batch.preview_data.fetch("sheets").each do |config|
            sheet = workbook.sheet(config.fetch("name"))
            mapping = @batch.mapping_config.fetch("sheets").fetch(config.fetch("key"))
            ((config.fetch("header_row") + 1)..sheet.last_row.to_i).each do |number|
              process_row(sheet, config, number, mapping)
              @batch.refresh_counts!
              @batch.broadcast_progress!
            end
          end
        end
        @batch.refresh_counts!
        @batch.update!(status: @batch.failed_rows.positive? ? :completed_with_errors : :completed, completed_at: Time.current)
        @batch.broadcast_progress!
      rescue StandardError => error
        # Unexpected infrastructure failures stop the job; successful rows remain replay checkpoints.
        @batch.refresh_counts!
        @batch.update!(status: :failed, fatal_error: "Import interrupted (#{error.class.name}); inspect local diagnostics and resume.", completed_at: Time.current)
        @batch.broadcast_progress!
        raise
      end
    end

    private

    def process_row(sheet, config, number, mapping)
      row = @batch.import_rows.find_or_initialize_by(source_sheet: config.fetch("name"), source_row_number: number)
      return if row.persisted? && row.status != "pending"
      raw, data = RowData.read(sheet, config, number, mapping)
      row.assign_attributes(raw_data: raw, normalized_data: data, row_type: RowClassifier.classify(data))
      row.save!
      attempts = 0
      begin
        # Retry the complete row only after Rails has rolled back its savepoint.
        # Retrying SQL inside an aborted PostgreSQL transaction cannot recover uniqueness failures.
        ImportRow.transaction(requires_new: true) do
          row.reload
          case row.row_type
          when "finish_result"
            athlete = AthleteResolver.new(@batch, data).resolve
            result = RaceResultWriter.new(@batch, athlete, data).write
            row.update!(athlete: athlete, race_result: result, status: "imported", error_message: nil)
          when "athlete_profile", "registration"
            useful = data["id_number"].to_s.match?(/\A\d{13}\z/) || data["passport_number"].present? || data["full_name"].present? || (data["first_name"].present? && data["last_name"].present?)
            if useful
              athlete = AthleteResolver.new(@batch, data).resolve
              row.update!(athlete: athlete, status: "imported", error_message: nil)
            else
              row.update!(status: "skipped", error_message: "No importable athlete profile")
            end
          else
            row.update!(status: "skipped", error_message: "No mapped result or athlete profile")
          end
        end
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < 3
        raise
      end
    rescue *ROW_ERRORS => error
      row.reload.update!(status: "failed", error_message: row_error_message(error))
    end

    def row_error_message(error)
      # Never persist SQL, bind values, filesystem paths or infrastructure secrets into the UI.
      case error
      when ActiveRecord::RecordNotUnique then "Identity or result changed concurrently; review and upload a corrected workbook."
      when ActiveRecord::RecordInvalid then error.record.errors.full_messages.to_sentence
      else error.message
      end
    end
  end
end
