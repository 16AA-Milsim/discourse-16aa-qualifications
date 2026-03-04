import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class QualificationsRoute extends DiscourseRoute {
  @service router;

  model() {
    return ajax("/qualifications.json").catch((error) => {
      if (error?.jqXHR?.status === 403) {
        return this.router.transitionTo("discovery.latest");
      }

      throw error;
    });
  }
}
