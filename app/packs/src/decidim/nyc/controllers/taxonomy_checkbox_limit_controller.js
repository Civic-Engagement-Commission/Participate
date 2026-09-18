import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { max: Number };

  update() {
    const boxes = Array.from(this.element.querySelectorAll('input[type="checkbox"]'));
    const checkedCount = boxes.filter((box) => box.checked).length;
    const atMax = this.maxValue > 0 && checkedCount >= this.maxValue;

    boxes.forEach((box) => {
      box.disabled = atMax && !box.checked;
    });
  }
}
