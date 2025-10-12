const CSS_VAR_PATTERN = /^var\(--[a-z0-9_-]+\)$/i;
const HEX_PATTERN = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
const NAMED_PATTERN = /^[a-z]+$/i;

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

  return null;
}

function applyColours(root) {
  root
    .querySelectorAll("td[data-background-color]")
    .forEach((cell) => {
      const color = cell.dataset.backgroundColor;
      const hasQualification = cell.dataset.hasQualification === "true";

      cell.classList.remove("has-background-color");
      cell.style.removeProperty("background-color");

      if (hasQualification || !color) {
        return;
      }

      const sanitized = sanitize(color);
      if (sanitized) {
        cell.style.backgroundColor = sanitized;
        cell.classList.add("has-background-color");
      }
    });
}
