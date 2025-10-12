import Component from "@glimmer/component";
import { action } from "@ember/object";

const CSS_VAR_PATTERN = /^var\(--[a-z0-9_-]+\)$/i;
const HEX_PATTERN = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
const NAMED_PATTERN = /^[a-z]+$/i;

function sanitize(color) {
  const trimmed = (color || "").trim();
  if (!trimmed) {
    return null;
  }

  if (CSS_VAR_PATTERN.test(trimmed)) {
    return trimmed;
  }

  if (HEX_PATTERN.test(trimmed)) {
    return trimmed;
  }

  if (NAMED_PATTERN.test(trimmed)) {
    return trimmed.toLowerCase();
  }

  return null;
}

export default class QualificationCellComponent extends Component {
  get cellClass() {
    const base = "qualification-cell";
    const extra = this.args.cellClass;

    return extra ? `${base} ${extra}` : base;
  }

  @action
  applyBackground(element) {
    const color = this.args.backgroundColor;
    const earned = this.args.hasQualification;

    element.classList.remove("has-background-color");
    element.style.removeProperty("background-color");

    if (!color || earned) {
      return;
    }

    const sanitized = sanitize(color);
    if (sanitized) {
      element.style.backgroundColor = sanitized;
      element.classList.add("has-background-color");
    }
  }

  @action
  clearBackground(element) {
    element.classList.remove("has-background-color");
    element.style.removeProperty("background-color");
  }
}
