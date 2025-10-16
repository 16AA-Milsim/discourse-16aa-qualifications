const CSS_VAR_PATTERN = /^var\(--[a-z0-9_-]+\)$/i;
const HEX_PATTERN = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
const NAMED_PATTERN = /^[a-z]+$/i;
const RGB_PATTERN =
  /^rgba?\(\s*(\d{1,3}\s*,\s*){2}\d{1,3}(?:\s*,\s*(0|1|0?\.\d+))?\s*\)$/i;

export default function enhanceQualificationTable(root) {
  if (!root) {
    return;
  }

  applyColours(root);
}

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

function applyColours(root) {
  root
    .querySelectorAll("td[data-background-color]")
    .forEach((cell) => {
      const color = cell.dataset.backgroundColor;
      const hasQualification = cell.dataset.hasQualification === "true";

      cell.classList.remove("has-background-color", "qualification-cell--overlay");
      cell.style.removeProperty("--qualification-overlay");

      if (hasQualification || !color) {
        return;
      }

      const sanitized = sanitize(color);
      if (sanitized) {
        cell.style.setProperty("--qualification-overlay", sanitized);
        cell.classList.add("qualification-cell--overlay");
      }
    });
}
