import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class Admin16AAQualificationsController extends Controller {
  @tracked groupPriorityText = "[]";
  @tracked qualificationsText = "[]";
  @tracked isSaving = false;

  loadConfig(model) {
    this.applyConfig(model);
  }

  applyConfig(model) {
    this.groupPriorityText = this.stringify(model?.group_priority);
    this.qualificationsText = this.stringify(model?.qualifications);
  }

  stringify(value) {
    if (!value) {
      return "[]";
    }

    try {
      return JSON.stringify(value, null, 2);
    } catch (e) {
      return "[]";
    }
  }

  parse(text, label) {
    try {
      const parsed = JSON.parse(text || "[]");
      if (!Array.isArray(parsed)) {
        throw new Error(`${label} must be an array`);
      }
      return parsed;
    } catch (error) {
      throw new Error(`${label}: ${error.message}`);
    }
  }

  @action
  saveConfig() {
    let groupPriority;
    let qualifications;

    try {
      groupPriority = this.parse(this.groupPriorityText, "Group priority");
      qualifications = this.parse(this.qualificationsText, "Qualification definitions");
    } catch (error) {
      this.flash(error.message, "error");
      return;
    }

    this.isSaving = true;

    ajax("/16aa-qualifications/admin/config", {
      type: "PUT",
      data: {
        config: {
          group_priority: groupPriority,
          qualifications,
        },
      },
    })
      .then((response) => {
        if (response?.success) {
          this.flash(I18n.t("sixteen_aa_qualifications.admin.save_success"), "success");
          if (response.config) {
            this.applyConfig(response.config);
          }
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.isSaving = false;
      });
  }

  @action
  resetToDefaults() {
    this.isSaving = true;

    ajax("/16aa-qualifications/admin/config/reset", {
      type: "POST",
    })
      .then((response) => {
        if (response?.success && response.config) {
          this.applyConfig(response.config);
          this.flash(I18n.t("sixteen_aa_qualifications.admin.reset_success"), "success");
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.isSaving = false;
      });
  }
}
