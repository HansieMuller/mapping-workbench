class ImportBatchChannel < ApplicationCable::Channel
  def subscribed
    batch = current_user.import_batches.find_by(id: params[:id])
    return reject unless batch
    stream_for batch
    transmit batch.progress_payload
  end
end
