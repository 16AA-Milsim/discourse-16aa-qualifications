import Component from "@glimmer/component";
import { action } from "@ember/object";

const CSS_VAR_PATTERN = /^var\(--[a-z0-9_-]+\)$/i;
const HEX_PATTERN = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
const NAMED_PATTERN = /^[a-z]+$/i;
const RGB_PATTERN = /^rgba?\(\s*(\d{1,3}\s*,\s*){2}\d{1,3}(?:\s*,\s*(0|1|0?\.\d+))?\s*\)$/i;

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

  if (RGB_PATTERN.test(trimmed)) {
    return trimmed.replace(/\s+/g, "");
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
    // Remove any old inline background color and class
    element.classList.remove("has-background-color");
    element.style.removeProperty("background-color");
    // Do NOT set backgroundColor or add has-background-color here anymore.
    // The overlay is now handled by CSS class and variable set elsewhere.
  }

  @action
  clearBackground(element) {
    element.classList.remove("has-background-color");
    element.style.removeProperty("background-color");
  }
}
