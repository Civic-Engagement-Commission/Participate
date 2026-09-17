import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    filters: Array,
    inputType: String,
    inputOptions: Array
  };

  connect() {
    this.entries = this.parse(this.element.value);
    this.element.hidden = true;

    this.wrapper = document.createElement("div");
    this.wrapper.classList.add("taxonomy-filter-json-editor");
    this.element.insertAdjacentElement("afterend", this.wrapper);

    this.filtersValue.forEach((filter) => this.renderRow(filter));
  }

  disconnect() {
    this.wrapper?.remove();
    this.element.hidden = false;
  }

  parse(raw) {
    try {
      return JSON.parse(raw || "{}");
    } catch {
      return {};
    }
  }

  renderRow(filter) {
    const row = document.createElement("div");
    row.classList.add("row", "column", "mb-2");

    const label = document.createElement("label");
    label.textContent = filter.name;
    row.append(label);

    const input = this.inputTypeValue === "select" ? this.buildSelect(filter) : this.buildNumber(filter);
    input.addEventListener("change", () => this.sync());
    row.append(input);
    this.wrapper.append(row);
  }

  buildNumber(filter) {
    const input = document.createElement("input");
    input.type = "number";
    input.min = "1";
    input.value = this.entries[filter.id] || 1;
    input.dataset.filterId = filter.id;
    return input;
  }

  buildSelect(filter) {
    const select = document.createElement("select");
    select.dataset.filterId = filter.id;
    this.inputOptionsValue.forEach((optionValue) => {
      const option = document.createElement("option");
      option.value = optionValue;
      option.textContent = optionValue;
      option.selected = this.entries[filter.id] === optionValue;
      select.append(option);
    });
    return select;
  }

  sync() {
    const result = {};
    this.wrapper.querySelectorAll("[data-filter-id]").forEach((input) => {
      result[input.dataset.filterId] = this.inputTypeValue === "select" ? input.value : Number(input.value);
    });
    this.element.value = JSON.stringify(result);
  }
}
