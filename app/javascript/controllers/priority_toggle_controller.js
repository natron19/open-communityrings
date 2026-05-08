import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // No initialization needed — all state is in the DOM via Turbo Stream updates
  }
}
