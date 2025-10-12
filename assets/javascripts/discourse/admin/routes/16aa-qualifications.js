import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class Admin16AAQualificationsRoute extends Route {
  model() {
    return ajax("/16aa-qualifications/admin/config.json");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.loadConfig(model);
  }
}
