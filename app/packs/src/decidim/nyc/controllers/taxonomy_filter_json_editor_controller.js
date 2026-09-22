import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    filters: Array,
    inputType: String,
    inputOptions: Array
  };

  connect() {
    this.entries = this.parse(this.element.value);

    this.wrapper = document.createElement("div");
    this.wrapper.classList.add("taxonomy-filter-json-editor");
    this.element.insertAdjacentElement("afterend", this.wrapper);

    this.renderRows(this.filtersValue);
    this.observeFiltersTable();
  }

  disconnect() {
    this.observer?.disconnect();
    this.wrapper?.remove();
  }

  observeFiltersTable() {
    const container = this.element.closest("form")?.querySelector(".js-current-filters");
    if (!container) return;

    this.observer = new MutationObserver(() => this.renderRows(this.readFilters(container)));
    this.observer.observe(container, { childList: true, subtree: true });
  }

  readFilters(container) {
    const filters = [];
    let pendingId = null;

    container.querySelectorAll("tbody > *").forEach((node) => {
      if (node.tagName === "INPUT") {
        pendingId = node.value;
      } else if (node.tagName === "TR" && pendingId) {
        filters.push({ id: pendingId, name: node.querySelector("td")?.textContent.trim() });
        pendingId = null;
      }
    });

    return filters;
  }

  renderRows(filters) {
    this.captureEntries();
    this.wrapper.replaceChildren();
    filters.forEach((filter) => this.renderRow(filter));
    this.sync();
  }

  captureEntries() {
    this.wrapper.querySelectorAll("[data-filter-id]").forEach((input) => {
      this.entries[input.dataset.filterId] = this.inputTypeValue === "select" ? input.value : Number(input.value);
    });
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
    row.classList.add("mt-2");

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
      option.value = optionValue.value;
      option.textContent = optionValue.label;
      option.selected = this.entries[filter.id] === optionValue.value;
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
