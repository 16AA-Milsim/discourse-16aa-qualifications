import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPlugins16aaQualificationsRoute extends DiscourseRoute {
  async model() {
    if (!this.currentUser?.staff) {
      return { disallow: true };
    }

    return ajax("/admin/plugins/16aa-qualifications.json");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setup(model);
  }
}
