import Controller from "@ember/controller";
import { action } from "@ember/object";
import { formatUsername } from "discourse/lib/utilities";
import applyQualificationColours from "../lib/qualification-cell-colours";

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

    return qualification.earned ? qualification.name || qualification.badge : null;
  };

  backgroundColor = (qual) => {
    if (!qual || qual.earned) {
      return null;
    }

    const color = qual.empty_color;
    if (!color) {
      return null;
    }

    return color.startsWith("--") ? `var(${color})` : color;
  };

  @action
  applyColours(element) {
    applyQualificationColours(element);
  }
}
