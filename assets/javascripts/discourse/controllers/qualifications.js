import Controller from "@ember/controller";
import { action } from "@ember/object";
import { formatUsername } from "discourse/lib/utilities";
import applyQualificationColours from "../lib/qualification-cell-colours";
import getURL from "discourse/lib/get-url";

const COLOR_TOKENS = [
  "--16aa-qual-red",
  "--16aa-qual-orange",
  "--16aa-qual-yellow",
  "--16aa-qual-green",
];

const LIGHT_COLOR_FALLBACKS = {
  "--16aa-qual-red": "#c53f3f",
  "--16aa-qual-orange": "#f78b2d",
  "--16aa-qual-yellow": "#f5c14c",
  "--16aa-qual-green": "#2f9e44",
};

const DARK_COLOR_FALLBACKS = {
  "--16aa-qual-red": "#ff6b6b",
  "--16aa-qual-orange": "#ffa94d",
  "--16aa-qual-yellow": "#facc15",
  "--16aa-qual-green": "#4ade80",
};

export default class QualificationsController extends Controller {
  get memberRows() {
    const groups = this.model?.groups || [];
    const rows = [];

    groups.forEach((group) => {
      const label = group?.label || "";
      (group?.users || []).forEach((user) => {
        rows.push({ user: this.decorateUser(user), groupLabel: label });
      });
    });

    return rows;
  }

  get qualifications() {
    const config = this.model?.config || {};
    if (Array.isArray(config.qualifications) && config.qualifications.length) {
      return config.qualifications;
    }

    return [
      ...(Array.isArray(config.qualification_groups) ? config.qualification_groups : []),
      ...(Array.isArray(config.standalone_qualifications)
        ? config.standalone_qualifications
        : []),
    ];
  }

  get hasRows() {
    return this.memberRows.length > 0;
  }

  decorateUser(user) {
    if (!user) {
      return user;
    }

    const qualifications = Array.isArray(user.qualifications)
      ? user.qualifications
      : [
          ...(Array.isArray(user.qualification_groups)
            ? user.qualification_groups
            : []),
          ...(Array.isArray(user.standalone_qualifications)
            ? user.standalone_qualifications
            : []),
        ];

    return {
      ...user,
      qualifications,
      displayName: this.displayNameFor(user),
    };
  }

  get schemeType() {
    if (typeof window === "undefined") {
      return "light";
    }

    try {
      const value = getComputedStyle(document.body).getPropertyValue(
        "--scheme-type"
      );
      if (value?.trim()) {
        return value.trim() === "dark" ? "dark" : "light";
      }
    } catch (e) {
      // fall through to matchMedia or default
    }

    if (window.matchMedia?.("(prefers-color-scheme: dark)")?.matches) {
      return "dark";
    }

    return "light";
  }

  get isDarkScheme() {
    return this.schemeType === "dark";
  }

  get colorPalette() {
    const scheme = this.schemeType;
    if (!this._colorPalette || this._colorPalette.scheme !== scheme) {
      const basePalette =
        scheme === "dark"
          ? { ...DARK_COLOR_FALLBACKS }
          : { ...LIGHT_COLOR_FALLBACKS };

      if (typeof window !== "undefined") {
        const container = document.querySelector(".qualifications-page");
        if (container) {
          const styles = getComputedStyle(container);
          COLOR_TOKENS.forEach((token) => {
            const value = styles.getPropertyValue(token)?.trim();
            if (value) {
              basePalette[token] = value;
            }
          });
        }
      }

      this._colorPalette = { scheme, values: basePalette };
    }

    return this._colorPalette.values;
  }

  resolveThemeColor(token) {
    return this.colorPalette[token] || null;
  }

  displayNameFor(user) {
    const username = user?.username || "";
    let formatted = formatUsername(username) || username;

    const prefix = (user?.rank_prefix || "").trim();
    if (prefix) {
      const normalized = formatted.toLowerCase();
      const expected = `${prefix} `.toLowerCase();
      if (!normalized.startsWith(expected)) {
        formatted = `${prefix} ${formatted}`.trim();
      }
    }

    return formatted;
  }

  hasQualification = (qualification) => {
    if (!qualification) {
      return false;
    }

    if (Array.isArray(qualification.levels)) {
      return Boolean(qualification.earned);
    }

    return Boolean(qualification.earned);
  };

  qualificationLabel = (qualification) => {
    if (!qualification) {
      return null;
    }

    if (Array.isArray(qualification.levels)) {
      const earned = qualification.earned;
      if (!earned) {
        return null;
      }

      return earned.label || earned.badge;
    }

    if (!qualification.earned) {
      return null;
    }

    return qualification.name || qualification.badge || "✔";
  };

  badgeDetails = (qualification) => {
    if (!qualification) {
      return null;
    }

    if (Array.isArray(qualification.levels)) {
      return qualification.earned?.badge_details || null;
    }

    return qualification.badge_details || null;
  };

  badgeLink = (badgeDetails) => {
    if (!badgeDetails) {
      return null;
    }

    let url = badgeDetails.url;

    if (!url) {
      const id = badgeDetails.id;
      const slug = badgeDetails.slug || badgeDetails.name;

      if (id) {
        url = `/badges/${id}`;
        if (slug) {
          url += `/${slug}`;
        }
      }
    }

    return url ? getURL(url) : null;
  };

  badgeDescription = (badgeDetails) => {
    if (!badgeDetails) {
      return null;
    }

    return (
      badgeDetails.long_description_text ||
      badgeDetails.description_text ||
      this.stripHtml(badgeDetails.long_description) ||
      this.stripHtml(badgeDetails.description) ||
      null
    );
  };

  displayValueFor = (qualification) => {
    if (!this.hasQualification(qualification)) {
      return "";
    }

    if (Array.isArray(qualification.levels)) {
      return this.qualificationLabel(qualification) || "";
    }

    return "✔";
  };

  stripHtml(source) {
    if (!source) {
      return null;
    }

    if (typeof document === "undefined") {
      return source;
    }

    const div = document.createElement("div");
    div.innerHTML = source;
    const text = div.textContent || div.innerText || "";
    return text.trim() || null;
  }

  backgroundColor = (qual) => {
    if (!qual || qual.earned) {
      return null;
    }

    const rawColor = qual.empty_color;
    if (!rawColor) {
      return null;
    }

    if (typeof rawColor === "string") {
      const trimmed = rawColor.trim();
      if (!trimmed) {
        return null;
      }

      if (trimmed.startsWith("--")) {
        return this.resolveThemeColor(trimmed);
      }

      return trimmed;
    }

    return rawColor;
  };

  @action
  applyColours(element) {
    this._colorPalette = null;
    applyQualificationColours(element);
  }
}
