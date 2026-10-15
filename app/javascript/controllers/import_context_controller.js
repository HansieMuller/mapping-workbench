import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["event", "race", "eventFields", "raceFields"]
  connect() { this.update() }
  update() {
    const eventId = this.eventTarget.value
    Array.from(this.raceTarget.options).forEach(option => {
      option.hidden = Boolean(option.value && eventId && option.dataset.eventId !== eventId)
    })
    const selected = this.raceTarget.selectedOptions[0]
    if (selected?.hidden) this.raceTarget.value = ""
    this.eventFieldsTarget.hidden = Boolean(eventId || this.raceTarget.value)
    this.raceFieldsTarget.hidden = Boolean(this.raceTarget.value)
  }
}
