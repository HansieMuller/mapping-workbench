import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "errors", "button"]
  connect() { this.validate() }
  validate() {
    const errors = []
    let results = 0
    this.sheetTargets.forEach(sheet => {
      const fields = Array.from(sheet.querySelectorAll("select")).map(s => s.value).filter(v => v !== "unused")
      if (new Set(fields).size !== fields.length) errors.push(`${sheet.dataset.sheetName}: each destination can be mapped once.`)
      if (fields.includes("finish_time")) results += 1
      if (fields.includes("finish_time") || fields.includes("finish_status")) {
        if (!(fields.includes("id_number") || fields.includes("full_name") || (fields.includes("first_name") && fields.includes("last_name")))) {
          errors.push(`${sheet.dataset.sheetName}: map ID number, full name, or first and last name.`)
        }
      }
    })
    if (results === 0) errors.push("Map finish time on at least one results sheet.")
    this.errorsTarget.textContent = errors.join(" ")
    this.buttonTarget.disabled = errors.length > 0
    return errors.length === 0
  }
  submit(event) { if (!this.validate()) event.preventDefault() }
}
