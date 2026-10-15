class ImportBatchChannel < ApplicationCable::Channel
  def subscribed
    batch = current_user.import_batches.find_by(id: params[:id])
    return reject unless batch
    stream_for batch
    transmit batch.progress_payload
  end
  # Read durable state after the browser receives subscription confirmation.
  # Publications can race with Redis attaching a new/reconnected subscriber.
  def refresh
    batch = current_user.import_batches.find_by(id: params[:id])
    return reject unless batch
    transmit batch.progress_payload
  end
end
