import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  preserveMappings() {
    this.element.querySelectorAll("[data-preserved-mapping]").forEach(input => input.remove())
    document.querySelectorAll("select[data-import-mapping-target='select']").forEach(select => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = select.name
      input.value = select.value
      input.dataset.preservedMapping = "true"
      this.element.append(input)
    })
  }
}
