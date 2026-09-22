import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select/dist/cjs/tom-select.popular";

export default class extends Controller {
  static values = { max: Number, placeholder: String };

  connect() {
    this.tomSelect = new TomSelect(this.element, {
      plugins: ["remove_button"],
      maxItems: this.maxValue > 0 ? this.maxValue : null,
      placeholder: this.placeholderValue,
      hidePlaceholder: true,
      create: false
    });
  }

  disconnect() {
    this.tomSelect?.destroy();
  }
}
