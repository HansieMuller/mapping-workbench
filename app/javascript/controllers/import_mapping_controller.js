import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  connect() { this.update() }
  update() {
    const used = new Set(this.selectTargets.map(s => s.value).filter(v => v !== "unused"))
    this.selectTargets.forEach(select => Array.from(select.options).forEach(option => {
      option.disabled = option.value !== "unused" && used.has(option.value) && option.value !== select.value
    }))
  }
}
