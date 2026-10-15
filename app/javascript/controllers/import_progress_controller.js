import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { id: Number, status: String }
  static targets = ["status", "total", "imported", "failed", "skipped", "bar", "percentage", "connection"]
  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create({ channel: "ImportBatchChannel", id: this.idValue }, {
      connected: () => { this.connectionTarget.textContent = "Live updates connected"; this.element.dataset.cableConnected = "true"; this.subscription.perform("refresh") },
      disconnected: () => { this.connectionTarget.textContent = "Disconnected. Refresh to read durable progress." },
      rejected: () => { this.connectionTarget.textContent = "Progress access denied" },
      received: progress => this.update(progress)
    })
  }
  disconnect() { this.subscription?.unsubscribe(); this.consumer?.disconnect() }
  update(progress) {
    if (!progress || typeof progress.status !== "string") return
    this.element.dataset.cableStatus = progress.status
    this.element.dataset.cableMessages = String(Number(this.element.dataset.cableMessages || 0) + 1)
    this.statusTarget.textContent = progress.status.replaceAll("_", " ")
    this.statusTarget.className = `badge ${progress.status}`
    this.totalTarget.textContent = progress.total_rows
    this.importedTarget.textContent = progress.imported_rows
    this.failedTarget.textContent = progress.failed_rows
    this.skippedTarget.textContent = progress.skipped_rows
    this.barTarget.value = progress.percentage
    this.percentageTarget.textContent = progress.percentage
    const previousStatus = this.statusValue
    this.statusValue = progress.status
    if (previousStatus !== progress.status && ["completed", "completed_with_errors", "failed"].includes(progress.status)) {
      this.statusValue = progress.status
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}
