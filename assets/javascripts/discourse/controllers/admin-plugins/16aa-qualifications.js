import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class Admin16AAQualificationsController extends Controller {
  @service toasts;

  @tracked disallow = false;
  @tracked groupPriorityText = "[]";
  @tracked isSaving = false;
  @tracked qualificationsText = "[]";

  setup(model) {
    this.disallow = !!model?.disallow;
    if (this.disallow) {
      return;
    }

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
    } catch {
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
      this.toasts.error({
        data: { message: error.message },
      });
      return;
    }

    this.isSaving = true;

    const serializedGroupPriority = JSON.stringify(groupPriority);
    const serializedQualifications = JSON.stringify(qualifications);

    ajax("/admin/plugins/16aa-qualifications/config", {
      type: "PUT",
      data: {
        config: {
          group_priority: serializedGroupPriority,
          qualifications: serializedQualifications,
        },
      },
    })
      .then((response) => {
        if (response?.success) {
          this.toasts.success({
            data: { message: i18n("sixteen_aa_qualifications.admin.save_success") },
          });

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

    ajax("/admin/plugins/16aa-qualifications/config/reset", {
      type: "POST",
    })
      .then((response) => {
        if (response?.success && response.config) {
          this.applyConfig(response.config);
          this.toasts.success({
            data: { message: i18n("sixteen_aa_qualifications.admin.reset_success") },
          });
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.isSaving = false;
      });
  }
}
